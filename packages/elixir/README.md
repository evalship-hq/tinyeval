# tinyeval

Test your Elixir app's AI calls the way you test the rest of it: write test cases, run `mix tinyeval`, and see which replies pass.

## Install

Add it to `mix.exs`, then run `mix deps.get`:

```elixir
def deps do
  [{:tinyeval, "~> 0.11", only: [:dev, :test], runtime: false}]
end
```

## Write an eval

`evals/support.sh` lists the test cases. Its `worker` line starts your app once and sends it every input:

```bash
worker mix run --no-start evals/worker.exs

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  contains "30 days"
```

`evals/worker.exs` answers each input:

```elixir
Tinyeval.worker(fn input ->
  if System.get_env("ANTHROPIC_API_KEY") in [nil, ""],
    do: raise(Tinyeval.CouldntRun, "ANTHROPIC_API_KEY is not set")

  MyApp.Support.answer(input)
end)
```

Replies go to stdout, so `Tinyeval.worker/1` sends everything else your app prints, `Logger` included, to stderr. It does this first and then starts your app. That's why the worker runs `mix run --no-start`: with a plain `mix run`, your app's start-up logs would end up in the first reply.

## Run it

```sh
mix tinyeval
```

Options pass through, such as `mix tinyeval -n 3 -k refund`. `mix tinyeval -h` lists them. It compiles your project first, so the workers have nothing to compile. Press Ctrl-C twice to stop it.

## Couldn't run

Raise `Tinyeval.CouldntRun` when the AI call itself failed: no key, a 401, a 429, a 5xx, a timeout. tinyeval then counts the run apart from the failures, and still exits 1. Any other error becomes the reply, so the eval fails, and its stack trace goes to stderr.

Elixir has no official Anthropic or OpenAI SDK, so `Tinyeval.CouldntRun` is the only error the worker reads this way. With Req, map the responses yourself:

```elixir
case Req.post(req, json: request) do
  {:ok, %{status: 200, body: body}} -> reply_text(body)
  {:ok, %{status: status}} when status in [401, 429] or status >= 500 ->
    raise Tinyeval.CouldntRun, "anthropic: #{status}"
  # A 400 comes from the request your app built, so it's graded.
  {:ok, %{status: status, body: body}} -> "error: #{status} #{inspect(body)}"
  {:error, exception} -> raise Tinyeval.CouldntRun, Exception.message(exception)
end
```

## Needs bash

tinyeval is a bash script. It needs bash 3.2 or later, which macOS and Linux have. On Windows, install Git for Windows.

## Updating

```sh
mix deps.update tinyeval
```

Dependabot and Renovate see new versions in `mix.lock` and open the pull request for you. A repo that commits its own `./tinyeval` keeps running that file: delete it to run this package's.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every grading line, the judge and the options
- [elixir-llm-evals](https://github.com/evalship-hq/elixir-llm-evals): a Req app with its evals
