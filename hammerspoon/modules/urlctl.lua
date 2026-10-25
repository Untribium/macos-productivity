-- modules/urlctl.lua — fixed hammerspoon:// control endpoints (SETUP.md §0, §8).
--
-- The deliberately narrow alternative to hs.ipc. hs.ipc lets any process
-- running as this user execute arbitrary Lua, and so borrow Hammerspoon's
-- Accessibility grant (keylogging, synthetic input). These endpoints take no
-- parameters and do one fixed thing each, so the worst a hostile caller can
-- do is trigger a reload or rewrite the files in .live/.
--
--   open -g hammerspoon://reload   reload the config
--   open -g hammerspoon://status   rewrite .live/status.json and .live/console.txt
--
-- Both files are also written on every load, so a changed `loaded` time is how
-- a caller confirms a reload actually happened. Module state comes from
-- diag.provide(); see modules/diag.lua.
--
-- RULE: never add an endpoint that reads its params, evaluates anything, or
-- writes outside .live/. That would make this hs.ipc again.

local diag = require("modules.diag")
local log  = diag.logger("urlctl")

local M = {}

local function writeStatus(ctx, reason)
  local status = {
    reason        = reason,
    loaded        = M.loadedAt,
    written       = os.date("%Y-%m-%dT%H:%M:%S"),
    hsVersion     = hs.processInfo.version,
    configdir     = hs.configdir,
    watching      = ctx.root,
    accessibility = hs.accessibilityState(),
    modules       = diag.collect(),
  }
  local ok, json = pcall(hs.json.encode, status, true)
  if not ok then
    -- a provider returned something unencodable; still say so in the file
    json = hs.json.encode({ reason = reason, written = status.written,
                            error = "status not encodable: " .. tostring(json) }, true)
  end
  local path = diag.dir .. "/status.json"
  local f, err = io.open(path, "w")
  if not f then return log.e("cannot write %s: %s", path, err) end
  f:write(json, "\n")
  f:close()
  diag.dumpConsole()
end

-- ctx: { root = watched dir }. Call after every other module has started, so
-- the load-time status includes their providers.
function M.start(ctx)
  M.loadedAt = os.date("%Y-%m-%dT%H:%M:%S")
  hs.urlevent.bind("reload", function() log.i("reload requested"); hs.reload() end)
  hs.urlevent.bind("status", function() writeStatus(ctx, "requested") end)
  writeStatus(ctx, "load")
end

return M
