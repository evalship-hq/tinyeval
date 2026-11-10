# Tinyeval

Find out whether a prompt or model change breaks your .NET app's AI replies. You list test cases in a short bash file, and tinyeval runs your own C# code against them.

## Install

`Tinyeval.Tool` is the `tinyeval` command. `Tinyeval` is the library your worker project references.

```sh
dotnet new tool-manifest -o .config   # once per repo: .config/dotnet-tools.json
dotnet tool install Tinyeval.Tool
dotnet add evals/Worker package Tinyeval
```

## Example

`evals/support.sh` holds the test cases. Its `worker` line starts your compiled worker once, not once per test case:

```bash
worker dotnet evals/Worker/bin/Release/net10.0/Worker.dll

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/Worker/Program.cs` passes each input to your app:

```csharp
using Anthropic;
using Support;
using Tinyeval;

SupportBot? bot = null;
await Worker.Run(async message =>
{
    if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ANTHROPIC_API_KEY")))
        throw new CouldntRunException("ANTHROPIC_API_KEY isn't set");
    bot ??= new SupportBot(new AnthropicClient()); // built on the first input
    return await bot.Answer(message);
});
```

`Worker.Run` takes a `Func<string, Task<string>>` like this one, or a plain `Func<string, string>`.

## Run it

```sh
dotnet build -c Release
dotnet tinyeval
```

`dotnet tinyeval -n 3` runs each test case three times. A global install (`dotnet tool install -g Tinyeval.Tool`) gives you `tinyeval` on your PATH instead.

## Errors

- **`throw new CouldntRunException("reason")`** marks the test case as couldn't run. tinyeval counts it apart from the failures, and still exits 1.
- **Exceptions from the official `Anthropic` and `OpenAI` packages** count as couldn't run when your code isn't the cause: status 401, 408, 429 or 500 and up, network errors and timeouts. The library finds them by type name, so it depends on neither package.
- **Any other exception** becomes the reply, such as `InvalidOperationException: no order id`, so the eval fails. The stack trace goes to stderr.

## Stdout carries the replies

When `Worker.Run` starts, it keeps the real stdout for replies and points `Console.Out` at stderr. So build your app after that, on the first input as above or in a `Lazy<T>`. Anything written to `Console.Out` before `Worker.Run` lands in the first reply.

.NET can't move the stdout handle itself. A child process you start, or native code, still writes to the real stdout. Set `RedirectStandardOutput` on its `ProcessStartInfo`, or send its output to stderr.

## Needs bash

tinyeval is a bash script, so it needs bash 3.2 or later. macOS and Linux have it. On Windows, the tool uses the bash from Git for Windows.

## Updating

```sh
dotnet tool update Tinyeval.Tool
dotnet add evals/Worker package Tinyeval
```

The versions live in `.config/dotnet-tools.json` and your worker's `.csproj`, which Dependabot and Renovate both read, so new releases arrive as pull requests. Keep the two packages on the same version.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the model judge included.
- [csharp-llm-evals](https://github.com/evalship-hq/csharp-llm-evals): a C# support bot whose evals run on every pull request.
