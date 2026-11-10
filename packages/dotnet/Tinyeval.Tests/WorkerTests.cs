using System.Net;
using System.Text;

[assembly: CollectionBehavior(DisableTestParallelization = true)] // one test swaps Console.Out

namespace Tinyeval.Tests
{
    public class WorkerTests
    {
        // tinyeval's side of the pipe: inputs each followed by a NUL, handed over a few bytes per read.
        static async Task<string[]> Serve(Func<string, Task<string>> answer, string stdin, int bytesPerRead = 4096)
        {
            var replies = new MemoryStream();
            await Worker.Serve(new Trickle(Encoding.UTF8.GetBytes(stdin), bytesPerRead), replies, answer);
            var text = Encoding.UTF8.GetString(replies.ToArray());
            Assert.EndsWith("\0", text);
            return text[..^1].Split('\0');
        }

        static Task<string[]> Serve(Func<string, string> answer, string stdin, int bytesPerRead = 4096) =>
            Serve(input => Task.FromResult(answer(input)), stdin, bytesPerRead);

        static Func<string, string> Throws(Func<string, Exception> error) => input => throw error(input);

        class Trickle(byte[] data, int bytesPerRead) : MemoryStream(data)
        {
            public override int Read(byte[] buffer, int offset, int count) =>
                base.Read(buffer, offset, Math.Min(count, bytesPerRead));
        }

        [Fact]
        public async Task SeveralInputsInOneRead() =>
            Assert.Equal(["You said: a", "You said: b", "You said: "], await Serve(i => "You said: " + i, "a\0b\0\0"));

        [Fact]
        public async Task AnInputSplitAcrossReadsInsideACharacter() =>
            Assert.Equal(["naïve 日本語 ✓", "x"], await Serve(i => i, "naïve 日本語 ✓\0x\0", bytesPerRead: 2));

        [Fact]
        public async Task RepliesAreUtf8WithoutNuls()
        {
            var replies = new MemoryStream();
            await Worker.Serve(new MemoryStream([0]), replies, _ => Task.FromResult("é\0!"));
            Assert.Equal([0xC3, 0xA9, (byte)'!', 0], replies.ToArray());
        }

        [Fact]
        public async Task AnAsyncAnswer() =>
            Assert.Equal(["later: a"], await Serve(async i => { await Task.Yield(); return "later: " + i; }, "a\0"));

        [Fact]
        public void TheAppsOutputGoesToStderr()
        {
            var (stdout, stderr) = (Console.Out, Console.Error);
            var caught = new StringWriter();
            try
            {
                Console.SetError(caught);
                var replies = Worker.TakeStdout(); // not disposed: on Windows it is the process's stdout handle
                Console.WriteLine("app loaded");
                Assert.Equal("app loaded" + Environment.NewLine, caught.ToString());
                Assert.True(replies.CanWrite);
            }
            finally
            {
                Console.SetOut(stdout);
                Console.SetError(stderr);
            }
        }

        [Fact]
        public async Task CouldntRun() =>
            Assert.Equal(["#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n", "#tinyeval couldnt_run CouldntRunException\n"],
                await Serve(Throws(i => new CouldntRunException(i)), "ANTHROPIC_API_KEY\nisn't  set\0 \0"));

        [Fact]
        public async Task SdkErrorsThatArentTheAppsFault() =>
            Assert.Equal(
                [
                    "#tinyeval couldnt_run anthropic: 429 AnthropicRateLimitException\n",
                    "#tinyeval couldnt_run anthropic: 529 AnthropicApiException\n",
                    "#tinyeval couldnt_run anthropic: AnthropicIOException Connection refused\n",
                    "#tinyeval couldnt_run openai: 401 ClientResultException\n",
                    "#tinyeval couldnt_run openai: ClientResultException Connection refused\n",
                    "#tinyeval couldnt_run anthropic: 429 AnthropicRateLimitException\n",
                ],
                await Serve(Throws(i => i switch
                {
                    "429" => new Anthropic.Exceptions.AnthropicRateLimitException(),
                    "529" => new Anthropic.Exceptions.AnthropicApiException((HttpStatusCode)529),
                    "network" => new Anthropic.Exceptions.AnthropicIOException(new HttpRequestException("Connection refused")),
                    "openai 401" => new System.ClientModel.ClientResultException(401, "HTTP 401"),
                    "openai network" => new System.ClientModel.ClientResultException(0, "Connection refused"),
                    _ => new AggregateException(new Anthropic.Exceptions.AnthropicRateLimitException()),
                }), "429\0529\0network\0openai 401\0openai network\0.Result\0"));

        [Fact]
        public async Task SdkErrorsThatAreTheReply() =>
            Assert.Equal(
                ["AnthropicApiException: Status Code: BadRequest", "ClientResultException: HTTP 404", "TaskCanceledException: A task was canceled."],
                await Serve(Throws(i => i switch
                {
                    "400" => new Anthropic.Exceptions.AnthropicApiException(HttpStatusCode.BadRequest),
                    "404" => new System.ClientModel.ClientResultException(404, "HTTP 404"),
                    _ => new TaskCanceledException(), // the app's own, not an SDK's timeout
                }), "400\0404\0canceled\0"));

        [Fact]
        public async Task AnAppErrorIsTheReplyAndTheWorkerGoesOn() =>
            Assert.Equal(["InvalidOperationException: boom", "You said: hi"],
                await Serve(i => i == "crash" ? throw new InvalidOperationException("boom") : "You said: " + i, "crash\0hi\0"));
    }
}

// Shaped like the SDKs' errors: the helper knows them by type name and status property.
namespace Anthropic.Exceptions
{
    public class AnthropicException(string message, Exception? inner = null) : Exception(message, inner);
    public class AnthropicApiException(HttpStatusCode status) : AnthropicException($"Status Code: {status}")
    {
        public HttpStatusCode StatusCode { get; } = status;
    }
    public class AnthropicRateLimitException() : AnthropicApiException(HttpStatusCode.TooManyRequests);
    public class AnthropicIOException(Exception inner) : AnthropicException("I/O exception", inner);
}

namespace System.ClientModel
{
    public class ClientResultException(int status, string message) : Exception(message)
    {
        public int Status { get; } = status;
    }
}
