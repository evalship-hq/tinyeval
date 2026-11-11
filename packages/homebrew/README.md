# tinyeval for Homebrew

Test the AI calls in your app with evals, from a C or C++ codebase or any other, with one command on your PATH.

## Install

```sh
brew install evalship-hq/tap/tinyeval
```

## Write an eval

`evals/support.sh` lists the test cases and how to grade each reply:

```bash
worker build/evalworker

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`build/evalworker` is your program. It starts once, reads each input up to a NUL byte on stdin, and prints the reply and a NUL byte:

```cpp
int main() {
    std::string input;
    while (std::getline(std::cin, input, '\0')) {
        const char* key = std::getenv("ANTHROPIC_API_KEY");
        std::string reply = key && *key
            ? support::answer(input)
            : "#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n";
        std::cout << reply << '\0' << std::flush;
    }
}
```

A reply that starts with `#tinyeval couldnt_run REASON` means the AI call couldn't run: no key, a rate limit, a server error, a timeout. tinyeval counts it apart from the failures, and the run still exits 1. Keep your app's own output on stderr, so it stays out of the replies.

## Run it

```sh
tinyeval
```

It needs bash 3.2 or later, which macOS and Linux have. A repo that commits its own `./tinyeval` runs that copy, at the version its evals were written for.

## Update

```sh
brew upgrade tinyeval
```

## Links

- https://tinyeval.com
- [Writing evals](https://github.com/evalship-hq/tinyeval#readme)
- [A C++ example repo](https://github.com/evalship-hq/cpp-llm-evals), and worker loops in 14 languages in [examples/workers](https://github.com/evalship-hq/tinyeval/tree/main/examples/workers)
