<?php

// Unit tests for worker.php: each runs a worker in its own php process, as tinyeval does, around a fake app with
// SDK-shaped errors. Run: php test/worker_test.php

$app = <<<'APP'
<?php
namespace Anthropic\Core\Exceptions {
    class APIException extends \Exception { public ?int $status = null; }
    class APIStatusException extends APIException {
        public function __construct(int $status) { $this->status = $status; parent::__construct("status $status"); }
    }
    class RateLimitException extends APIStatusException {}
    class BadRequestException extends APIStatusException {}
    class APIConnectionException extends APIException {}
    class APITimeoutException extends APIConnectionException {}
}
namespace OpenAI\Exceptions {
    final class ErrorException extends \Exception {
        public function __construct(private int $status) { parent::__construct('Incorrect API key provided'); }
        public function getStatusCode(): int { return $this->status; }
    }
    final class TransporterException extends \Exception {}
}
namespace {
    require $argv[1];
    echo "app loaded\n";
    system('echo system output');
    if (PHP_OS_FAMILY !== 'Windows') { // where the worker moves only PHP's own output
        proc_close(proc_open('echo child output', [], $pipes));
        file_put_contents('php://stdout', "stream output\n");
    }
    Tinyeval\worker(function (string $input): string {
        echo "app called\n";
        return match ($input) {
            'crash' => throw new RuntimeException('boom'),
            'no key' => throw new Tinyeval\CouldntRun("ANTHROPIC_API_KEY isn't\nset"),
            '429' => throw new Anthropic\Core\Exceptions\RateLimitException(429),
            '400' => throw new Anthropic\Core\Exceptions\BadRequestException(400),
            'timeout' => throw new Anthropic\Core\Exceptions\APITimeoutException('Request timed out.'),
            'openai 401' => throw new OpenAI\Exceptions\ErrorException(401),
            'openai offline' => throw new OpenAI\Exceptions\TransporterException('Could not resolve host'),
            'warning' => trigger_error('careful', E_USER_WARNING) ? 'warned' : '',
            'nul' => "a\0b",
            default => "You said: $input",
        };
    });
}
APP;
$appFile = tempnam(sys_get_temp_dir(), 'tinyeval-app');
file_put_contents($appFile, $app);

/** Writes each chunk to a new worker's stdin, then closes it. Returns the replies, stderr and the exit code. */
function run_worker(string ...$chunks): array
{
    global $appFile;
    $err = tempnam(sys_get_temp_dir(), 'tinyeval-err');
    $io = [['pipe', 'r'], ['pipe', 'w'], ['file', $err, 'w']];
    $proc = proc_open([PHP_BINARY, $appFile, dirname(__DIR__) . '/worker.php'], $io, $pipes);
    foreach ($chunks as $chunk) {
        fwrite($pipes[0], $chunk);
        fflush($pipes[0]);
        usleep(50000);
    }
    fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]);
    $code = proc_close($proc);
    $stderr = file_get_contents($err);
    unlink($err);
    return [explode("\0", $out), $stderr, $code];
}

$failed = 0;
function check(string $test, bool $ok, mixed $got): void
{
    global $failed;
    echo $ok ? "ok    $test\n" : "FAIL  $test, got " . var_export($got, true) . "\n";
    $failed += $ok ? 0 : 1;
}

[$replies, , $code] = run_worker("one\0two\0three\0partial");
check('several inputs in one chunk', $replies === ['You said: one', 'You said: two', 'You said: three', ''], $replies);
check('exits 0 at the end of input, dropping a partial input', $code === 0, $code);

$bytes = "naïve 日本語 ✓\0";
[$replies] = run_worker(substr($bytes, 0, 3), substr($bytes, 3, 6), substr($bytes, 9));
check('an UTF-8 input split across chunks inside a character', $replies === ['You said: naïve 日本語 ✓', ''], $replies);

[$replies, $err] = run_worker("hi\0warning\0");
check("the app's output stays off stdout", $replies === ['You said: hi', 'warned', ''], $replies);
$fd = PHP_OS_FAMILY === 'Windows' ? '' : 'child output\R+stream output\R+';
check('echo, system(), warnings, and on macOS and Linux child processes and php://stdout, go to stderr',
    (bool) preg_match("/app loaded\\R+system output\\R+{$fd}app called\\R+app called\\R.*careful/s", $err), $err);

[$replies] = run_worker("no key\0", "429\0", "timeout\0", "openai 401\0", "openai offline\0");
check("couldn't run", $replies === [
    "#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n",
    "#tinyeval couldnt_run anthropic: 429 RateLimitException\n",
    "#tinyeval couldnt_run anthropic: APITimeoutException\n",
    "#tinyeval couldnt_run openai: 401 ErrorException\n",
    "#tinyeval couldnt_run openai: TransporterException\n",
    '',
], $replies);

[$replies, $err, $code] = run_worker("crash\0", "400\0", "after\0");
check('other errors become the reply, and the worker goes on', $replies === [
    'RuntimeException: boom',
    'Anthropic\Core\Exceptions\BadRequestException: status 400',
    'You said: after',
    '',
], $replies);
check('with the stack trace on stderr', (bool) preg_match('/RuntimeException: boom in .*\RStack trace:\R#0/', $err), $err);
check('and exits 0', $code === 0, $code);

[$replies] = run_worker("nul\0");
check('NUL bytes are dropped from the reply', $replies === ['ab', ''], $replies);

unlink($appFile);
exit($failed ? 1 : 0);
