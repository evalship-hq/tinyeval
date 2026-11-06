// tinyeval worker in Go. In your eval file:
//
//	worker go run evals/worker.go
//
// Set up your app's clients in main, before the loop, so they start once per worker.
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

func reply(input string) string {
	return "You said: " + input // your app's AI call goes here
}

func main() {
	in := bufio.NewReader(os.Stdin)
	for {
		input, err := in.ReadString(0)
		if err != nil {
			return
		}
		fmt.Print(reply(strings.TrimSuffix(input, "\x00")), "\x00")
	}
}
