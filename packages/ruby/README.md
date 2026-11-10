# tinyeval

Test the AI calls in your Ruby or Rails app with evals, and run them in CI next to your other tests.

## Install

```sh
bundle add tinyeval --group development
```

## Write an eval

`evals/support.sh` lists the test cases and how to grade each reply:

```bash
worker bundle exec ruby evals/worker.rb

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/worker.rb` loads your app once and answers each test case:

```ruby
require "tinyeval/worker" # before your app, so its output stays off the replies
require_relative "../lib/support"

support = Support.new
Tinyeval.worker do |input|
  raise Tinyeval::CouldntRun, "ANTHROPIC_API_KEY isn't set" unless ENV["ANTHROPIC_API_KEY"]
  support.answer(input)
end
```

In a Rails app, Rails boots once per worker with this line, and the worker calls your own class:

```bash
worker bin/rails runner evals/worker.rb
```

## Run it

```sh
bundle exec tinyeval
```

## When the AI call fails

Raise `Tinyeval::CouldntRun` when the call can't run at all. tinyeval then counts the run as couldn't run, apart from the failures. Errors from the `anthropic` and `openai` gems count too when they are a 401, a 429, a 5xx, a timeout or a lost connection.

Any other error becomes the reply, so the eval fails. Its stack trace goes to stderr.

## Needs bash

tinyeval is a bash script. It runs on bash 3.2 or later: macOS and Linux have it, and on Windows it uses Git for Windows' bash.

## Updating

```sh
bundle update tinyeval
```

Dependabot and Renovate see new versions in your `Gemfile.lock`. A repo that commits its own `./tinyeval` file keeps running that file.

## More

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge and the options
- [evalship-hq/ruby-llm-evals](https://github.com/evalship-hq/ruby-llm-evals): a Ruby support bot with its evals in CI
