-- tinyeval worker in Lua. In your eval file:
--   worker lua evals/worker.lua
-- Require your app's modules at the top, so they load once per worker.

local function reply(input)
  return "You said: " .. input -- your app's AI call goes here
end

-- One byte at a time, as a longer read waits until it has every byte it asked for.
local input = {}
for byte in io.stdin:lines(1) do
  if byte == "\0" then
    io.stdout:write(reply(table.concat(input)), "\0")
    io.stdout:flush()
    input = {}
  else
    input[#input + 1] = byte
  end
end
