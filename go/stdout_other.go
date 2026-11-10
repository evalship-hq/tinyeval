//go:build !unix || solaris

package tinyeval

import "os"

// Windows, and Solaris, which has no dup2: only os.Stdout moves to stderr. That covers Go code and the child
// processes it starts with os.Stdout. Code that writes to the process's own standard output still reaches the replies.
func dupStdout() (*os.File, error) { return os.Stdout, nil }
