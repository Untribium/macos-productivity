-- modules/urlctl.lua — fixed hammerspoon:// control endpoints (SETUP.md §0, §8).
--
-- The deliberately narrow alternative to hs.ipc. hs.ipc lets any process
-- running as this user execute arbitrary Lua, and so borrow Hammerspoon's
-- Accessibility grant (keylogging, synthetic input). These endpoints take no
-- parameters and do one fixed thing each, so the worst a hostile caller can
-- do is trigger a reload or rewrite the status file.
--
--   open -g hammerspoon://reload   reload the config
--   open -g hammerspoon://status   rewrite the status file
--
-- The status file is also written on every load, so a changed `loaded` time
-- is how a caller confirms a reload actually happened.
--
-- RULE: never add an endpoint that reads its params, evaluates anything, or
-- writes anywhere but the status file. That would make this hs.ipc again.

local M = {}

local function sortedNames(byKeycode)
  local out = {}
  for kc in pairs(byKeycode or {}) do
    out[#out + 1] = hs.keycodes.map[kc] or tostring(kc)
  end
  table.sort(out)
  return out
end

local function writeStatus(ctx, reason)
  local tap = ctx.fnlayer.tap
  local status = {
    reason        = reason,
    loaded        = M.loadedAt,
    written       = os.date("%Y-%m-%dT%H:%M:%S"),
    hsVersion     = hs.processInfo.version,
    configdir     = hs.configdir,
    watching      = ctx.root,
    accessibility = hs.accessibilityState(),
    fnTap         = tap and tap:isEnabled() or false,
    fnBindings    = sortedNames(ctx.fnlayer.bindings),
  }
  local f, err = io.open(ctx.statusFile, "w")
  if not f then
    hs.printf("urlctl: cannot write %s: %s", ctx.statusFile, err)
    return
  end
  f:write(hs.json.encode(status, true), "\n")
  f:close()
end

-- ctx: { root = watched dir, statusFile = path, fnlayer = module }
function M.start(ctx)
  M.loadedAt = os.date("%Y-%m-%dT%H:%M:%S")
  hs.urlevent.bind("reload", function() hs.reload() end)
  hs.urlevent.bind("status", function() writeStatus(ctx, "requested") end)
  writeStatus(ctx, "load")
end

return M
