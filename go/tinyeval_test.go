package tinyeval

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"testing"
	"testing/iotest"
	"time"
)

func echo(input string) (string, error) { return "You said: " + input, nil }

func run(t *testing.T, in string, answer func(string) (string, error)) string {
	t.Helper()
	var out strings.Builder
	// One byte per read, so every input, and "ï" in "naïve", arrives split across reads.
	if err := serve(iotest.OneByteReader(strings.NewReader(in)), &out, answer); err != nil {
		t.Fatal(err)
	}
	return out.String()
}

func TestSeveralInputsInOneChunk(t *testing.T) {
	var out strings.Builder
	if err := serve(strings.NewReader("a\x00b\x00"), &out, echo); err != nil {
		t.Fatal(err)
	}
	if out.String() != "You said: a\x00You said: b\x00" {
		t.Errorf("got %q", out.String())
	}
}

func TestUTF8SplitAcrossReads(t *testing.T) {
	if got := run(t, "naïve 日本語 ✓\x00x\x00", echo); got != "You said: naïve 日本語 ✓\x00You said: x\x00" {
		t.Errorf("got %q", got)
	}
}

func TestNULBytesAreDroppedFromTheReply(t *testing.T) {
	if got := run(t, "a\x00", func(string) (string, error) { return "x\x00y", nil }); got != "xy\x00" {
		t.Errorf("got %q", got)
	}
}

func TestCouldntRun(t *testing.T) {
	got := run(t, "a\x00b\x00", func(input string) (string, error) {
		if input == "a" {
			return "", CouldntRun("ANTHROPIC_API_KEY\nisn't set")
		}
		return "", fmt.Errorf("support: %w", CouldntRun("timed out"))
	})
	if got != "#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n\x00#tinyeval couldnt_run timed out\n\x00" {
		t.Errorf("got %q", got)
	}
}

// Shaped like the SDKs' *Error: Anthropic's has a Type method, OpenAI's a Type field.
type anthropicError struct{ StatusCode int }

func (e *anthropicError) Error() string { return fmt.Sprintf("POST: %d", e.StatusCode) }
func (e *anthropicError) Type() string  { return "rate_limit_error" }

type openaiError struct {
	StatusCode int
	Type       string
}

func (e *openaiError) Error() string { return fmt.Sprintf("POST: %d %s", e.StatusCode, e.Type) }

type timeout struct{}

func (timeout) Error() string   { return "i/o timeout" }
func (timeout) Timeout() bool   { return true }
func (timeout) Temporary() bool { return true }

func TestSDKAndNetworkErrors(t *testing.T) {
	sdks["github.com/evalship-hq/tinyeval/go"] = "anthropic" // this test's types stand in for the SDK's
	defer delete(sdks, "github.com/evalship-hq/tinyeval/go")
	cases := []struct {
		err  error
		want string
	}{
		{&anthropicError{429}, "#tinyeval couldnt_run anthropic: 429 rate_limit_error\n"},
		{fmt.Errorf("support: %w", &anthropicError{529}), "#tinyeval couldnt_run anthropic: 529 rate_limit_error\n"},
		{errors.Join(errors.New("retry"), &openaiError{500, "server_error"}), "#tinyeval couldnt_run anthropic: 500 server_error\n"},
		{&openaiError{400, "invalid_request_error"}, "error: POST: 400 invalid_request_error"},
		{fmt.Errorf("dial: %w", timeout{}), "#tinyeval couldnt_run dial: i/o timeout\n"},
		{context.DeadlineExceeded, "#tinyeval couldnt_run context deadline exceeded\n"},
	}
	for _, c := range cases {
		if got := run(t, "a\x00", func(string) (string, error) { return "", c.err }); got != c.want+"\x00" {
			t.Errorf("%v: got %q, want %q", c.err, got, c.want)
		}
	}
}

func TestAppErrorsAndPanicsBecomeTheReply(t *testing.T) {
	got := run(t, "crash\x00panic\x00ok\x00", func(input string) (string, error) {
		switch input {
		case "crash":
			return "", errors.New("boom")
		case "panic":
			var m map[string]int
			m["x"] = 1
		}
		return echo(input)
	})
	if got != "error: boom\x00panic: assignment to entry in nil map\x00You said: ok\x00" {
		t.Errorf("got %q", got)
	}
}

// fd 1 itself, which a child process inherits. Kept in a variable, so it's never closed.
var fd1 = os.NewFile(1, "fd 1")

// The test binary again, as a worker: its stdout must hold only the replies.
func TestMain(m *testing.M) {
	if os.Getenv("TINYEVAL_TEST_WORKER") == "" {
		os.Exit(m.Run())
	}
	Worker(func(input string) (string, error) {
		fmt.Println("app called")
		child := exec.Command("cmd", "/c", "echo child output")
		child.Stdout = os.Stdout
		if runtime.GOOS != "windows" {
			child = exec.Command("sh", "-c", "echo child output")
			child.Stdout = fd1
		}
		return "You said: " + input, child.Run()
	})
}

func TestAppOutputStaysOffStdout(t *testing.T) {
	worker := exec.Command(os.Args[0])
	worker.Env = append(os.Environ(), "TINYEVAL_TEST_WORKER=1")
	var stdout, stderr strings.Builder
	worker.Stdout, worker.Stderr = &stdout, &stderr
	in, err := worker.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := worker.Start(); err != nil {
		t.Fatal(err)
	}
	in.Write([]byte("na\xc3")) // "ï" split across two writes
	time.Sleep(200 * time.Millisecond)
	in.Write([]byte("\xafve\x00b\x00"))
	in.Close()
	if err := worker.Wait(); err != nil {
		t.Fatalf("worker failed: %v\n%s", err, stderr.String())
	}
	if stdout.String() != "You said: naïve\x00You said: b\x00" {
		t.Errorf("stdout: %q", stdout.String())
	}
	if strings.Count(stderr.String(), "app called") != 2 || strings.Count(stderr.String(), "child output") != 2 {
		t.Errorf("stderr: %q", stderr.String())
	}
}
