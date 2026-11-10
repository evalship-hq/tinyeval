<?php

// Require this before your app. From here on, the app's output goes to stderr, and the replies to a copy of the
// real stdout. On macOS and Linux that happens at the file descriptor, so php://stdout and child processes go too.

namespace Tinyeval;

require_once __DIR__ . '/src/CouldntRun.php';

$GLOBALS['tinyeval_replies'] = fopen('php://stdout', 'wb'); // a copy of fd 1
if (PHP_OS_FAMILY === 'Windows') {
    // There, echo writes through C's stdout, which closing STDOUT closes too: catch PHP's own output instead.
    ob_start(function (string $output): string {
        fwrite(\STDERR, $output);
        return '';
    }, 1);
} else {
    fclose(\STDOUT); // frees fd 1, so the copy of stderr opened next takes it
    $GLOBALS['tinyeval_stdout'] = fopen('php://stderr', 'wb'); // kept: freeing it would close fd 1
}

/** Answers each input tinyeval sends, up to a NUL byte, with $answer's return value and a NUL byte. */
function worker(callable $answer): void
{
    $replies = $GLOBALS['tinyeval_replies'];
    $rest = '';
    while (!feof(\STDIN)) {
        $inputs = explode("\0", $rest . fread(\STDIN, 65536));
        $rest = array_pop($inputs); // a partial input waits for the rest of its bytes
        foreach ($inputs as $input) {
            try {
                $reply = (string) $answer($input);
            } catch (\Throwable $e) {
                if (($reason = couldnt_run($e)) !== null) {
                    $reply = '#tinyeval couldnt_run ' . trim(preg_replace('/\s+/', ' ', $reason)) . "\n";
                } else {
                    fwrite(\STDERR, "$e\n");
                    $reply = get_class($e) . ': ' . $e->getMessage(); // the reply, so the eval fails
                }
            }
            fwrite($replies, str_replace("\0", '', $reply) . "\0");
            fflush($replies);
        }
    }
}

/**
 * Why the AI call couldn't run, or null when the error is the app's. SDK errors are matched by name, so neither SDK
 * has to be installed: anthropic-ai/sdk, and openai-php/client since OpenAI has no official PHP SDK. They count on
 * 401, 429, 5xx, a lost connection or a timeout.
 */
function couldnt_run(\Throwable $e): ?string
{
    if ($e instanceof CouldntRun) {
        return $e->getMessage();
    }
    if ($e instanceof \Anthropic\Core\Exceptions\APIException) { // instanceof a missing class is false
        [$sdk, $status] = ['anthropic', $e->status];
    } elseif (str_starts_with(get_class($e), 'OpenAI\\Exceptions\\')) {
        $status = method_exists($e, 'getStatusCode') ? $e->getStatusCode() : ($e->response ?? null)?->getStatusCode();
        $sdk = 'openai';
    } else {
        return null;
    }
    $connection = $e instanceof \Anthropic\Core\Exceptions\APIConnectionException // timeouts are one too
        || $e instanceof \OpenAI\Exceptions\TransporterException;
    if (!$connection && $status !== 401 && $status !== 429 && $status < 500) {
        return null;
    }
    return "$sdk: " . ltrim($status . ' ' . substr(strrchr('\\' . get_class($e), '\\'), 1));
}
