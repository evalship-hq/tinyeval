#include "TinyevalStdout.h"
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

static int replies = 1;

int tinyeval_move_stdout(void) {
    int saved = fcntl(1, F_DUPFD_CLOEXEC, 3); // above stdin, stdout and stderr, and closed in child processes
    if (saved < 0 || dup2(2, 1) < 0) return 1;
    return saved;
}

// Runs as the worker starts, before main and any Swift code, so the app's print, C code and child processes all
// write to stderr.
__attribute__((constructor)) static void tinyeval_start(void) {
    replies = tinyeval_move_stdout();
    setvbuf(stdout, NULL, _IOLBF, 0); // stdout is a pipe now: line buffering keeps the app's lines in order with stderr's
}

int tinyeval_replies(void) { return replies; }
