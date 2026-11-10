// Package tinyeval answers the test cases of tinyeval (https://tinyeval.com) with your Go code.
//
// In evals/support.sh:
//
//	worker go run ./cmd/evalworker
//
// And in cmd/evalworker/main.go:
//
//	func main() {
//		bot := support.New()
//		tinyeval.Worker(func(input string) (string, error) {
//			return bot.Answer(context.Background(), input)
//		})
//	}
//
// Importing the package points stdout at stderr, so only replies reach tinyeval.
package tinyeval

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"reflect"
	"runtime/debug"
	"strings"
)

// CouldntRun is the error to return when the AI call couldn't run, such as on a missing key.
// tinyeval then counts the test case apart from the failures, and the run still exits 1.
// Any other error becomes the reply, so the eval fails.
type CouldntRun string

func (e CouldntRun) Error() string { return string(e) }

// The real stdout, kept for the replies before stdout moves to stderr.
var replies = takeStdout()

func takeStdout() *os.File {
	f, err := dupStdout()
	if err != nil {
		panic("tinyeval: couldn't point stdout at stderr: " + err.Error())
	}
	os.Stdout = os.Stderr
	return f
}

// Worker answers each input tinyeval sends with answer, until tinyeval closes stdin.
func Worker(answer func(input string) (string, error)) {
	if err := serve(os.Stdin, replies, answer); err != nil {
		fmt.Fprintln(os.Stderr, "tinyeval worker:", err)
		os.Exit(1)
	}
}

func serve(in io.Reader, out io.Writer, answer func(string) (string, error)) error {
	r := bufio.NewReader(in)
	for {
		input, err := r.ReadBytes(0)
		if err == io.EOF {
			return nil
		} else if err != nil {
			return err
		}
		reply := call(answer, string(input[:len(input)-1]))
		if _, err := io.WriteString(out, strings.ReplaceAll(reply, "\x00", "")+"\x00"); err != nil {
			return err
		}
	}
}

func call(answer func(string) (string, error), input string) (reply string) {
	defer func() {
		if p := recover(); p != nil {
			fmt.Fprintf(os.Stderr, "tinyeval worker: panic: %v\n%s", p, debug.Stack())
			reply = fmt.Sprint("panic: ", p)
		}
	}()
	reply, err := answer(input)
	if err == nil {
		return reply
	}
	if why, ok := couldntRun(err); ok {
		return "#tinyeval couldnt_run " + strings.NewReplacer("\r", " ", "\n", " ").Replace(why) + "\n"
	}
	fmt.Fprintf(os.Stderr, "tinyeval worker: %+v\n", err)
	return "error: " + err.Error()
}

// The official SDKs' API errors, by their type's package path: the helper doesn't import them.
var sdks = map[string]string{
	"github.com/anthropics/anthropic-sdk-go": "anthropic",
	"github.com/openai/openai-go":            "openai",
}

func couldntRun(err error) (string, bool) {
	var c CouldntRun
	if errors.As(err, &c) {
		return string(c), true
	}
	if why, status := sdkError(err); why != "" {
		return why, status == 401 || status == 429 || status >= 500
	}
	var netErr net.Error
	if errors.As(err, &netErr) || errors.Is(err, context.DeadlineExceeded) {
		return err.Error(), true
	}
	return "", false
}

// sdkError finds an SDK's *Error in err's chain, and says it as "anthropic: 529 overloaded_error".
func sdkError(err error) (string, int) {
	if many, ok := err.(interface{ Unwrap() []error }); ok {
		for _, err := range many.Unwrap() {
			if why, status := sdkError(err); why != "" {
				return why, status
			}
		}
		return "", 0
	}
	if err == nil {
		return "", 0
	}
	v := reflect.ValueOf(err)
	if s := reflect.Indirect(v); s.Kind() == reflect.Struct {
		for prefix, sdk := range sdks {
			if status := s.FieldByName("StatusCode"); strings.HasPrefix(s.Type().PkgPath(), prefix) && status.Kind() == reflect.Int {
				why := fmt.Sprintf("%s: %d", sdk, status.Int())
				kind := s.FieldByName("Type") // OpenAI's is a field, Anthropic's a method
				if m := v.MethodByName("Type"); m.IsValid() && m.Type().NumIn() == 0 && m.Type().NumOut() == 1 {
					kind = m.Call(nil)[0]
				}
				if kind.Kind() == reflect.String && kind.String() != "" {
					why += " " + kind.String()
				}
				return why, int(status.Int())
			}
		}
	}
	return sdkError(errors.Unwrap(err))
}
