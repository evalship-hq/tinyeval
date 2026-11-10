# tinyeval for Go

Catch the prompt or model change that makes your Go app's AI replies worse. You list test cases in a short bash file, and tinyeval runs them against your real code.

## Install

With Go 1.24 or later, add it to your module as a tool:

```sh
go get -tool github.com/evalship-hq/tinyeval/go/cmd/tinyeval
```

The same module holds the worker helper, so go.mod pins both at one version.

## Example

`evals/support.sh` lists the test cases. Its `worker` line builds your app once per worker, not once per test case:

```bash
worker go run ./cmd/evalworker

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`cmd/evalworker/main.go` hands each input to your code:

```go
func main() {
	bot := support.New()
	tinyeval.Worker(func(input string) (string, error) {
		if os.Getenv("ANTHROPIC_API_KEY") == "" {
			return "", tinyeval.CouldntRun("ANTHROPIC_API_KEY isn't set")
		}
		return bot.Answer(context.Background(), input)
	})
}
```

It imports `github.com/evalship-hq/tinyeval/go`, whose package name is `tinyeval`.

## Run it

```sh
go tool tinyeval        # every file in evals/
go tool tinyeval -n 3   # each test case 3 times; it passes when 2 do
```

To try it without touching go.mod: `go run github.com/evalship-hq/tinyeval/go/cmd/tinyeval@latest`.

It needs bash 3.2 or later: macOS, Linux, or Git for Windows.

## Errors

- **`tinyeval.CouldntRun("reason")`**, returned or wrapped with `%w`, marks the test case as couldn't run. tinyeval counts it apart from the failures, and the run still exits 1.
- **API errors** from the official SDKs, `anthropic-sdk-go` and `openai-go`, count as couldn't run when the status is 401, 429 or 500 and up. The helper matches them by type without importing either SDK.
- **Network errors**, a `net.Error` or `context.DeadlineExceeded`, count as couldn't run too.
- **Any other error** becomes the reply, `error: message`, so the eval fails. So does a panic, as `panic: value`, with its stack trace on stderr. The worker goes on with the next input.

## Stdout

When the helper's package initializes, it points stdout at stderr, child processes included, and keeps the real stdout for replies. Your `main` package initializes after it, so its prints go to stderr. Other packages that don't import the helper may initialize first, since Go orders them by import path: what their `init` functions print still reaches stdout and breaks the first reply. On Windows, only `os.Stdout` moves.

## Updating

```sh
go get -tool github.com/evalship-hq/tinyeval/go/cmd/tinyeval@latest
```

The version sits in go.mod, so Dependabot and Renovate open pull requests for new releases. `go tool tinyeval update` prints that command, and the run's summary names a new release.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge, and more
- [evalship-hq/go-llm-evals](https://github.com/evalship-hq/go-llm-evals): a Go support bot with its evals in CI
