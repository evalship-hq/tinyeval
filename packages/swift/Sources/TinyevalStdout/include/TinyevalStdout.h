// The worker's replies go to the real stdout, which tinyeval_replies() returns, and everything else to stderr.

/// Copies fd 1 to a new descriptor and returns it, then points fd 1 at stderr. Returns 1 when that fails.
int tinyeval_move_stdout(void);

/// The real stdout, saved when the worker started.
int tinyeval_replies(void);
