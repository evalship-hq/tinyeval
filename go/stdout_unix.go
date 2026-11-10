//go:build unix && !solaris

package tinyeval

import (
	"os"
	"syscall"
)

// A copy of fd 1 for the replies, then fd 1 pointed at stderr, so child processes and C code write there too.
func dupStdout() (*os.File, error) {
	fd, err := syscall.Dup(1)
	if err != nil {
		return nil, err
	}
	syscall.CloseOnExec(fd) // child processes don't get the replies
	if err := dup2(2, 1); err != nil {
		return nil, err
	}
	return os.NewFile(uintptr(fd), "/dev/stdout"), nil
}
