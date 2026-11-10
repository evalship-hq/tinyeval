//go:build unix && !linux && !solaris

package tinyeval

import "syscall"

func dup2(from, to int) error { return syscall.Dup2(from, to) }
