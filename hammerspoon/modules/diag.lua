-- modules/diag.lua — what a shell session can read about the running config.
--
-- Everything lands in <repo>/.live/ (gitignored), written by Hammerspoon and
-- read by whoever is debugging. Output only: nothing here reads input.
--
--   log.txt      timestamped lines from diag.logger(), kept across reloads
--   console.txt  the Hammerspoon console, dumped on load and on ://status
--   status.json  written by urlctl; includes every provider registered here
--
-- Usage in a module:
--   local diag = require("modules.diag")
--   local log  = diag.logger("winswitch")
--   log.i("cached %d windows", n)
--   diag.provide("winswitch", function() return { cache = ... } end)
--
-- Providers must return plain data (tables, strings, numbers, booleans) that
-- hs.json can encode. They run inside pcall, so one bad provider shows up as an
-- error string in status.json rather than breaking the dump.

local M = { providers = {} }

local MAX_LOG = 1024 * 1024   -- rotate to log.txt.1 past this

function M.setup(dir)
  M.dir = dir
  hs.fs.mkdir(dir)            -- returns nil if it already exists; that is fine
end

local function append(line)
  if not M.dir then return end
  local path = M.dir .. "/log.txt"
  local attr = hs.fs.attributes(path)
  if attr and attr.size > MAX_LOG then os.rename(path, path .. ".1") end
  local f = io.open(path, "a")
  if f then f:write(line, "\n"); f:close() end
end

-- Prints to the console as well, so nothing is lost if the file is unwritable.
function M.logger(name)
  local function level(tag)
    return function(fmt, ...)
      local msg = select("#", ...) > 0 and fmt:format(...) or fmt
      local line = ("%s %s %s: %s"):format(os.date("%Y-%m-%dT%H:%M:%S"), tag, name, msg)
      print(line)
      append(line)
    end
  end
  return { i = level("I"), w = level("W"), e = level("E"), d = level("D") }
end

function M.provide(name, fn) M.providers[name] = fn end

function M.collect()
  local out = {}
  for name, fn in pairs(M.providers) do
    local ok, v = pcall(fn)
    out[name] = ok and v or ("provider error: " .. tostring(v))
  end
  return out
end

-- The console is where errors from callbacks end up, so this is how a shell
-- session sees a stack trace.
function M.dumpConsole()
  if not M.dir then return end
  local f = io.open(M.dir .. "/console.txt", "w")
  if f then f:write(hs.console.getConsole() or "", "\n"); f:close() end
end

return M
