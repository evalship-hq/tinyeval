-- tinyeval's worker helper. Require it before your app's modules: from then on print, io.write and io.stdout
-- write to stderr, so the app's output stays off the replies. The replies go to the real stdout.
local tinyeval = {}

local replies = io.stdout
io.stdout = io.stderr
io.output(io.stderr)
function print(...)
  local parts = { ... }
  for i = 1, select("#", ...) do
    parts[i] = tostring(parts[i])
  end
  io.stderr:write(table.concat(parts, "\t", 1, select("#", ...)), "\n")
end

local CouldntRun = {}
CouldntRun.__tostring = function(e)
  return "couldn't run: " .. e.reason
end

-- error(tinyeval.CouldntRun("reason")) says the AI call couldn't run, such as without an API key. tinyeval then
-- counts the run apart from the failures, since it says nothing about the reply.
function tinyeval.CouldntRun(reason)
  return setmetatable({ reason = tostring(reason) }, CouldntRun)
end

local function answer(fn, input)
  local ok, reply, err = xpcall(function()
    return fn(input)
  end, function(e)
    if getmetatable(e) ~= CouldntRun then
      io.stderr:write(debug.traceback(tostring(e), 2), "\n")
    end
    return e
  end)
  if not ok and getmetatable(reply) == CouldntRun then
    return "#tinyeval couldnt_run " .. reply.reason:gsub("%s+", " "):match("^ ?(.-) ?$") .. "\n"
  elseif not ok then
    return "error: " .. tostring(reply) -- the reply, so the eval fails
  elseif reply == nil and err ~= nil then
    return "error: " .. tostring(err) -- Lua's nil, message
  end
  return tostring(reply)
end

-- Answers each input tinyeval sends, up to a NUL byte, with fn(input) and a NUL byte. Returns at the end of input.
function tinyeval.worker(fn)
  local input = {}
  while true do
    local byte = io.stdin:read(1) -- one at a time, as a longer read waits until it has every byte it asked for
    if not byte then
      return
    elseif byte == "\0" then
      replies:write((answer(fn, table.concat(input)):gsub("%z", "")), "\0")
      replies:flush()
      input = {}
    else
      input[#input + 1] = byte
    end
  end
end

return tinyeval
