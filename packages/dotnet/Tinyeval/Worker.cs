using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace Tinyeval
{
    /// <summary>
    /// Throw it when the AI call couldn't run, such as with no API key. tinyeval counts the test case apart from
    /// the failures, and still exits 1.
    /// </summary>
    public class CouldntRunException : Exception
    {
        /// <summary>The reason tinyeval shows, such as "ANTHROPIC_API_KEY isn't set".</summary>
        public CouldntRunException(string reason) : base(reason) { }
    }

    /// <summary>The worker for an eval file's <c>worker</c> line: it answers each input tinyeval sends.</summary>
    public static class Worker
    {
        /// <summary>
        /// Calls <paramref name="answer"/> with each input and sends back what it returns, until tinyeval is done.
        /// It first points Console.Out at stderr, so set your app up after it starts: on the first call, or in a Lazy.
        /// </summary>
        public static void Run(Func<string, string> answer) =>
            Run(input => Task.FromResult(answer(input))).GetAwaiter().GetResult();

        /// <inheritdoc cref="Run(Func{string, string})"/>
        public static Task Run(Func<string, Task<string>> answer) =>
            Serve(Console.OpenStandardInput(), TakeStdout(), answer);

        // Replies get the real stdout, and the app's Console.Out goes to stderr. .NET can't dup2, so child
        // processes and native code still write to the real stdout.
        internal static Stream TakeStdout()
        {
            var replies = Console.OpenStandardOutput();
            Console.Out.Flush();
            Console.SetOut(Console.Error);
            return replies;
        }

        internal static async Task Serve(Stream stdin, Stream replies, Func<string, Task<string>> answer)
        {
            var bytes = new BufferedStream(stdin);
            var input = new MemoryStream();
            for (int b; (b = bytes.ReadByte()) != -1;)
            {
                if (b != 0)
                {
                    input.WriteByte((byte)b);
                    continue;
                }
                // Decoded once whole, so a character split across reads survives.
                var reply = await Reply(answer, Encoding.UTF8.GetString(input.ToArray()));
                var output = Encoding.UTF8.GetBytes(reply.Replace("\0", "") + "\0");
                replies.Write(output, 0, output.Length);
                replies.Flush();
                input.SetLength(0);
            }
        }

        static async Task<string> Reply(Func<string, Task<string>> answer, string input)
        {
            try
            {
                return await answer(input) ?? "";
            }
            catch (Exception e)
            {
                if (e is AggregateException { InnerExceptions.Count: 1 } wrapped) e = wrapped.InnerException!; // from .Result
                var reason = e is CouldntRunException ? e.Message : SdkOutage(e);
                if (reason == null)
                {
                    Console.Error.WriteLine(e);
                    return $"{e.GetType().Name}: {e.Message}";
                }
                var line = string.Join(" ", reason.Split(default(char[]), StringSplitOptions.RemoveEmptyEntries));
                return $"#tinyeval couldnt_run {(line == "" ? nameof(CouldntRunException) : line)}\n";
            }
        }

        // Why an Anthropic or OpenAI SDK call couldn't run, or null when the error is the reply. The types are
        // matched by name, so neither SDK has to be referenced.
        static string? SdkOutage(Exception e)
        {
            for (var type = e.GetType(); type != null; type = type.BaseType)
            {
                switch (type.FullName)
                {
                    case "Anthropic.Exceptions.AnthropicIOException": // the network
                        return $"anthropic: {e.GetType().Name} {e.InnerException?.Message}";
                    case "Anthropic.Exceptions.AnthropicApiException":
                        return Status("anthropic", e, "StatusCode");
                    case "System.ClientModel.ClientResultException": // the OpenAI SDK's errors
                        return Status("openai", e, "Status");
                }
            }
            // Both SDKs time out with a TaskCanceledException thrown from their own code.
            if (e is OperationCanceledException)
            {
                foreach (var frame in new StackTrace(e).GetFrames() ?? new StackFrame[0])
                {
                    switch (frame.GetMethod()?.DeclaringType?.Assembly.GetName().Name)
                    {
                        case "Anthropic": return "anthropic: timeout";
                        case "OpenAI": case "System.ClientModel": return "openai: timeout";
                    }
                }
            }
            return null;
        }

        static string? Status(string sdk, Exception e, string property)
        {
            var value = e.GetType().GetProperty(property)?.GetValue(e);
            var status = value == null ? -1 : Convert.ToInt32(value);
            if (status == 0) return $"{sdk}: {e.GetType().Name} {e.Message}"; // no response: the network
            return status is 401 or 408 or 429 or >= 500 ? $"{sdk}: {status} {e.GetType().Name}" : null;
        }
    }
}
