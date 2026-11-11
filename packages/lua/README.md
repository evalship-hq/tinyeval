# tinyeval

Test the AI calls in your Lua app with evals, locally and in CI.

## Install

Into your project's own rocks tree, next to the rocks your app uses:

```sh
luarocks install --tree lua_modules tinyeval
```

If your app lists its rocks in a rockspec, add `"tinyeval >= 0.11"` to its `dependencies` instead.

## Write an eval

`evals/support.sh` holds the test cases and the checks on each reply:

```bash
worker lua evals/worker.lua

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/worker.lua` starts your app once, then answers every test case:

```lua
local tinyeval = require("tinyeval") -- first, so your app's output stays off the replies
local support = require("support").new()

tinyeval.worker(function(input)
  if (os.getenv("ANTHROPIC_API_KEY") or "") == "" then
    error(tinyeval.CouldntRun("ANTHROPIC_API_KEY isn't set"))
  end
  return support:answer(input)
end)
```

The worker line needs no paths: the `tinyeval` command puts its tree's rocks on `LUA_PATH` and `LUA_CPATH`.

## Run it

```sh
lua_modules/bin/tinyeval
```

## When the AI call fails

Lua has no official Anthropic or OpenAI SDK, so your code decides when a call couldn't run. Raise `tinyeval.CouldntRun(reason)` for a missing key, a 401, a 429, a 5xx, a timeout or a lost connection. tinyeval counts those apart from the failures. It still exits 1.

With LuaSocket, `http.request` returns `nil` and the error when no answer came back:

```lua
local ok, status = http.request(request)
if not ok or status == 401 or status == 429 or status >= 500 then
  error(tinyeval.CouldntRun("anthropic: " .. tostring(status)))
end
```

Any other error becomes the reply, as `error: MESSAGE`, so the eval fails. So does a `nil, message` return. The stack trace goes to stderr.

## Output from your app

Lua can't move the stdout file descriptor, so `require("tinyeval")` points `print`, `io.write` and `io.stdout` at stderr, and keeps the real stdout for the replies. Some output still reaches it: commands run with `os.execute` or `io.popen`, and C modules that print. Send those to stderr yourself, as in `os.execute("make >&2")`.

## Needs bash

tinyeval is one bash script, and needs bash 3.2 or later: macOS, Linux, or Git for Windows. The helper runs on Lua 5.1 to 5.5 and LuaJIT.

## Updating

```sh
luarocks install --tree lua_modules tinyeval
```

`tinyeval update` prints this command for the tree the rock is in, and tinyeval names it when a new release is out. Dependabot and Renovate don't read rockspecs, so they won't open these updates for you. A repo that commits its own `./tinyeval` keeps running that file.

## More

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge and the options
- [evalship-hq/lua-llm-evals](https://github.com/evalship-hq/lua-llm-evals): a Lua support bot with its evals in CI
