-- The helper's unit tests. Run from packages/lua: lua test/worker_test.lua
-- Each test runs a worker in its own lua process, as tinyeval does, and writes its stdin in separate writes.
local i = 0
while arg[i - 1] do
  i = i - 1
end
local lua = arg[i] -- the interpreter running these tests

local APP = [[
local tinyeval = require("tinyeval")
print("app loaded", 1)
io.write("io.write\n")
io.stdout:write("io.stdout\n")

-- An HTTP call the way LuaSocket returns it: nil, a reason and the status, which is nil when no answer came back.
local function call(input)
  if input == "429" then return nil, "anthropic: 429 rate_limit_error", 429 end
  if input == "400" then return nil, "anthropic: 400 invalid_request_error", 400 end
  if input == "offline" then return nil, "anthropic: connection refused" end
  return "You said: " .. input .. " (" .. #input .. " bytes)"
end

tinyeval.worker(function(input)
  print("app called")
  if input == "crash" then error("boom") end
  if input == "no key" then error(tinyeval.CouldntRun("ANTHROPIC_API_KEY isn't\nset")) end
  if input == "nul" then return "a\0b" end
  local answer, err, status = call(input)
  if answer then return answer end
  if not status or status == 401 or status == 429 or status >= 500 then error(tinyeval.CouldntRun(err)) end
  return nil, err
end)
]]

local function read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local app, out, err = os.tmpname(), os.tmpname(), os.tmpname()
local file = assert(io.open(app, "wb"))
file:write(APP)
file:close()

-- Starts the worker with each argument as one write to its stdin. Returns its replies, its stderr and whether it
-- exited 0.
local function run(...)
  local writes = {}
  for n, chunk in ipairs({ ... }) do
    writes[n] = "printf '" .. chunk:gsub(".", function(c)
      return ("\\%03o"):format(c:byte())
    end) .. "'"
  end
  local status = os.execute(('{ %s; } | %s -e "package.path=\'./?.lua;\'..package.path" %s >%s 2>%s'):format(
    table.concat(writes, "; sleep 0.1; "), lua, app, out, err))
  local replies, text = {}, read(out)
  for reply in text:gmatch("([^%z]*)%z") do
    replies[#replies + 1] = reply
  end
  assert(text:sub(-1) == "\0" or text == "", "the replies don't end with a NUL byte")
  return replies, read(err), status == true or status == 0
end

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.stderr:write(("not ok: %s\n  got:  %q\n  want: %q\n"):format(name, tostring(got), tostring(want)))
  end
end

local replies, stderr, ok = run("one\0two\0three\0")
check("several inputs in one write", table.concat(replies, "|"),
  "You said: one (3 bytes)|You said: two (3 bytes)|You said: three (5 bytes)")
check("exits 0 at the end of input", ok, true)

local bytes = "naïve 日本語 ✓\0" -- ï, 日 and ✓ are split across writes
replies = run(bytes:sub(1, 3), bytes:sub(4, 9), bytes:sub(10, 19), bytes:sub(20), "partial")
check("one input split across writes, inside characters", table.concat(replies, "|"),
  "You said: naïve 日本語 ✓ (" .. #bytes - 1 .. " bytes)")

replies, stderr = run("hi\0")
check("the app's output stays off stdout", table.concat(replies, "|"), "You said: hi (2 bytes)")
check("the app's output goes to stderr", stderr, "app loaded\t1\nio.write\nio.stdout\napp called\n")

replies = run("no key\0", "429\0", "offline\0")
check("couldn't run", table.concat(replies, "|"), "#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n"
  .. "|#tinyeval couldnt_run anthropic: 429 rate_limit_error\n|#tinyeval couldnt_run anthropic: connection refused\n")

replies, stderr, ok = run("crash\0", "400\0", "nul\0", "after\0")
check("an app error becomes the reply", replies[1]:match("^error: .*: boom$") ~= nil, true)
check("with its stack trace on stderr", stderr:match(": boom\nstack traceback:\n") ~= nil, true)
check("nil and a message become the reply", replies[2], "error: anthropic: 400 invalid_request_error")
check("NUL bytes are dropped from the reply", replies[3], "ab")
check("the worker goes on after errors", replies[4], "You said: after (5 bytes)")
check("and exits 0", ok, true)

os.remove(app)
os.remove(out)
os.remove(err)
if failures > 0 then
  os.exit(1)
end
print("ok: the worker helper's tests pass")
