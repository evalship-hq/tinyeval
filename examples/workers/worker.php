<?php
// tinyeval worker in PHP. In your eval file:
//   worker php evals/worker.php
// Laravel: load your app once, above the loop:
//   require __DIR__ . '/../vendor/autoload.php';
//   $app = require __DIR__ . '/../bootstrap/app.php';
//   $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

function reply(string $input): string
{
    return "You said: " . $input; // your app's AI call goes here
}

$rest = '';
while (!feof(STDIN)) {
    $inputs = explode("\0", $rest . fread(STDIN, 65536));
    $rest = array_pop($inputs);
    foreach ($inputs as $input) {
        fwrite(STDOUT, reply($input) . "\0");
        fflush(STDOUT);
    }
}
