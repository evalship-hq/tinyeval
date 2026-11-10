package tinyeval

import "syscall"

// Some Linux ports, like arm64, have no dup2.
func dup2(from, to int) error { return syscall.Dup3(from, to, 0) }
