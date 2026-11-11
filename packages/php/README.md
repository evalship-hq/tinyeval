# tinyeval

Test the AI calls in your PHP or Laravel app with evals, and run them in CI next to PHPUnit.

## Install

```sh
composer require --dev evalship/tinyeval
```

## Write an eval

`evals/support.sh` lists the test cases and how to grade each reply:

```bash
worker php evals/worker.php

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/worker.php` starts your app once and answers each test case:

```php
<?php
require __DIR__ . '/../vendor/evalship/tinyeval/worker.php'; // first, so your app's output stays off the replies
require __DIR__ . '/../vendor/autoload.php';

$support = new App\Support();
Tinyeval\worker(function (string $input) use ($support): string {
    if (!getenv('ANTHROPIC_API_KEY')) {
        throw new Tinyeval\CouldntRun("ANTHROPIC_API_KEY isn't set");
    }
    return $support->answer($input);
});
```

In a Laravel app, boot it once above the worker, and resolve your own class from the container:

```php
$app = require __DIR__ . '/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$support = $app->make(App\Support::class);
```

## Run it

```sh
vendor/bin/tinyeval
```

## When the AI call fails

Throw `Tinyeval\CouldntRun` when the call can't run at all. tinyeval counts that test case as couldn't run, apart from the failures, and the run still exits 1. Errors from `anthropic-ai/sdk` and `openai-php/client` count too when they are a 401, a 429, a 5xx, a timeout or a lost connection.

Any other exception becomes the reply, so the eval fails. Its stack trace goes to stderr.

## Your app's output

On macOS and Linux, a worker sends all of stdout to stderr, so nothing your app prints mixes into a reply: `echo`, warnings, `php://stdout` and child processes. PHP's `STDOUT` constant is closed there, so write to `php://stdout` instead.

On Windows, it moves PHP's own output, such as `echo` and warnings. `php://stdout` and child processes still write to stdout there.

## Needs bash

tinyeval is a bash script. It runs on bash 3.2 or later: macOS and Linux have it, and on Windows `vendor/bin/tinyeval` uses Git for Windows' bash.

## Updating

```sh
composer require --dev evalship/tinyeval
```

With no version, Composer moves to the newest release. `composer update` stays inside your `^0.x` range, which never takes a new 0.x minor.

Dependabot and Renovate see new versions in your `composer.lock`. A repo that commits its own `./tinyeval` file keeps running that file.

## More

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge and the options
- [evalship-hq/php-llm-evals](https://github.com/evalship-hq/php-llm-evals): a PHP support bot with its evals in CI
- This package is built from `packages/php` in [evalship-hq/tinyeval](https://github.com/evalship-hq/tinyeval). Send issues and pull requests there.
