-- modules/urlctl.lua — fixed hammerspoon:// control endpoints (SETUP.md §0, §8).
--
-- A narrow interface in place of hs.ipc. NOT a security boundary (SETUP.md
-- §8): anything running as this user can already write the config, which
-- this file is part of. The narrowness is about keeping the surface small
-- and predictable, not about keeping an attacker out.
--
--   open -g hammerspoon://reload   reload the config
--   open -g hammerspoon://status   rewrite .live/status.json and .live/console.txt
--   open -g hammerspoon://probe    call run() on probes/active.lua, if loaded
--
-- Both files are also written on every load, so a changed `loaded` time is how
-- a caller confirms a reload actually happened. Module state comes from
-- diag.provide(); see modules/diag.lua.
--
-- RULE: endpoints take no params. Code to run comes from files in the repo
-- (probes/), which are in git or deliberately gitignored, never from the URL.

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

local function runProbe(ctx)
  local probe = ctx.probe
  if not (probe and probe.run) then return log.w("probe requested, none loaded") end
  local ok, err = xpcall(probe.run, debug.traceback)
  if not ok then log.e("probe run failed: %s", err) end
  writeStatus(ctx, "probe")
end

-- ctx: { root = watched dir, probe = loaded probe table or nil }. Call after
-- every other module has started, so the load-time status includes their
-- providers.
function M.start(ctx)
  M.loadedAt = os.date("%Y-%m-%dT%H:%M:%S")
  hs.urlevent.bind("reload", function() log.i("reload requested"); hs.reload() end)
  hs.urlevent.bind("status", function() writeStatus(ctx, "requested") end)
  hs.urlevent.bind("probe",  function() runProbe(ctx) end)
  writeStatus(ctx, "load")
end

return M
