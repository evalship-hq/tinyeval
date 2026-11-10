// Command tinyeval runs the tinyeval in this module with bash. Add it to your module as a tool:
//
//	go get -tool github.com/evalship-hq/tinyeval/go/cmd/tinyeval
//	go tool tinyeval
//
// It doesn't import the worker helper, which moves stdout.
package main

import (
	"bytes"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
)

// The repo's tinyeval: go/prepare.sh copies it in, and a release commits it on the go/vX.Y.Z tag.
//
//go:embed tinyeval
var runner []byte

const update = "go get -tool github.com/evalship-hq/tinyeval/go/cmd/tinyeval@latest"

func main() {
	path, err := writeRunner()
	if err != nil {
		fail("couldn't write the bundled tinyeval to a file: %v", err)
	}
	bash := findBash()
	args := append([]string{"bash", path}, os.Args[1:]...)
	env := append(os.Environ(), "TINYEVAL_PACKAGE_UPDATE="+update)
	if runtime.GOOS != "windows" {
		fail("couldn't start bash: %v", syscall.Exec(bash, args, env))
	}
	// Windows can't replace this process with bash, so it waits for it, and leaves Ctrl-C to bash.
	signal.Ignore(os.Interrupt)
	cmd := exec.Command(bash, args[1:]...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr, cmd.Env = os.Stdin, os.Stdout, os.Stderr, env
	var exit *exec.ExitError
	if err := cmd.Run(); errors.As(err, &exit) {
		os.Exit(exit.ExitCode())
	} else if err != nil {
		fail("couldn't start bash: %v", err)
	}
}

// The runner needs a real file, so its $0 works: one per version in the user's cache folder, or in temp.
func writeRunner() (string, error) {
	_, version, _ := bytes.Cut(runner, []byte("\n_te_version="))
	version, _, _ = bytes.Cut(version, []byte("\n"))
	dirs := []string{os.TempDir()}
	if cache, err := os.UserCacheDir(); err == nil {
		dirs = append([]string{cache}, dirs...)
	}
	var err error
	for _, dir := range dirs {
		path := filepath.Join(dir, "tinyeval", "tinyeval-"+string(version))
		if have, err := os.ReadFile(path); err == nil && bytes.Equal(have, runner) {
			return path, nil
		}
		// Through a temporary file, so a tinyeval starting at the same time never runs half of it.
		tmp := fmt.Sprintf("%s.%d.tmp", path, os.Getpid())
		if err = os.MkdirAll(filepath.Dir(path), 0o755); err == nil {
			if err = os.WriteFile(tmp, runner, 0o644); err == nil {
				if err = os.Rename(tmp, path); err == nil {
					return path, nil
				}
				os.Remove(tmp)
			}
		}
	}
	return "", err
}

// On Windows, Git for Windows' bash comes before a bash on PATH, which may be WSL's.
func findBash() string {
	var tries []string
	if runtime.GOOS == "windows" {
		if git, err := exec.LookPath("git"); err == nil {
			tries = append(tries, filepath.Join(filepath.Dir(filepath.Dir(git)), "bin", "bash.exe"))
		}
		tries = append(tries, `C:\Program Files\Git\bin\bash.exe`)
	}
	for _, bash := range tries {
		if _, err := os.Stat(bash); err == nil {
			return bash
		}
	}
	bash, err := exec.LookPath("bash")
	if err != nil && runtime.GOOS == "windows" {
		fail("tinyeval needs bash from Git for Windows: https://git-scm.com/download/win")
	} else if err != nil {
		fail("tinyeval needs bash 3.2 or later: %v", err)
	}
	return bash
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "tinyeval: "+format+"\n", args...)
	os.Exit(2)
}
