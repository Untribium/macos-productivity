-- winswitch.lua -- cross-space MRU window switcher
--
-- Works around the fact that no Hammerspoon API can enumerate windows on
-- inactive spaces. Instead we retain hs.window handles as we see them and
-- reuse them later; the handles stay valid off-space even though discovery
-- does not.
--
-- Usage in ~/.hammerspoon/init.lua:
--     local ws = require("winswitch")
--     ws.start()

local M = {}

--------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------

M.mods      = { "alt" }
M.nextKey   = "tab"
M.prevKey   = "`"      -- alt-` steps backwards; shift-tab is awkward to bind
M.maxShown  = 10       -- rows in the overlay; cycling still covers everything
M.textSize  = 15

--------------------------------------------------------------------------
-- cache
--------------------------------------------------------------------------

local cache = {}   -- id -> { win, id, app, title, space, seen }
local seq   = 0    -- monotonic counter; better than timestamps for ordering

local function safe(w, fn)
  local ok, v = pcall(fn, w)
  if ok then return v end
  return nil
end

-- Record (or refresh) a window. Keeps last-known app/title if the window is
-- currently off-space and unreadable.
local function touch(w)
  if not w then return end
  local id = safe(w, function(x) return x:id() end)
  if not id then return end
  if safe(w, function(x) return x:isStandard() end) ~= true then return end

  local title = safe(w, function(x) return x:title() end)
  local app   = safe(w, function(x) return x:application():name() end)
  local sp    = hs.spaces.windowSpaces(id)

  seq = seq + 1
  local e = cache[id] or {}
  e.win   = w
  e.id    = id
  e.title = (title and title ~= "" and title) or e.title or "(untitled)"
  e.app   = app or e.app or "?"
  e.space = (sp and sp[1]) or e.space
  e.seen  = seq
  cache[id] = e
end

-- Seed from whatever is reachable right now (i.e. the current space).
local function seed()
  for _, w in ipairs(hs.window.allWindows()) do touch(w) end
end

-- Drop dead windows and refresh space assignments in one pass. Window IDs get
-- recycled after an app restarts, so this is what keeps stale entries out.
local function prune()
  local valid = {}
  for _, spaceList in pairs(hs.spaces.allSpaces() or {}) do
    for _, sid in ipairs(spaceList) do
      for _, wid in ipairs(hs.spaces.windowsForSpace(sid) or {}) do
        valid[wid] = sid
      end
    end
  end
  for id, e in pairs(cache) do
    if not valid[id] then cache[id] = nil else e.space = valid[id] end
  end
end

local function ordered()
  prune()
  local out = {}
  for _, e in pairs(cache) do out[#out + 1] = e end
  table.sort(out, function(a, b) return a.seen > b.seen end)
  return out
end

M.cache   = cache      -- exposed for poking at in the console
M.ordered = ordered

--------------------------------------------------------------------------
-- overlay
--------------------------------------------------------------------------

local S = { active = false, idx = 1, list = {}, alertId = nil, tap = nil }

local function render()
  if S.alertId then hs.alert.closeSpecific(S.alertId) end

  local here  = hs.spaces.focusedSpace()
  local lines = {}
  local first = math.max(1, math.min(S.idx - 3, #S.list - M.maxShown + 1))
  local last  = math.min(#S.list, first + M.maxShown - 1)

  for i = first, last do
    local e    = S.list[i]
    local mark = (i == S.idx) and "\226\150\184 " or "   "
    local away = (e.space and e.space ~= here) and ("  [space " .. e.space .. "]") or ""
    lines[#lines + 1] = string.format("%s%s \226\128\148 %s%s", mark, e.app, e.title, away)
  end

  S.alertId = hs.alert.show(table.concat(lines, "\n"),
                            { textSize = M.textSize, radius = 8 },
                            hs.screen.mainScreen(), 10)
end

local function finish()
  if not S.active then return end
  S.active = false
  if S.tap then S.tap:stop() end
  if S.alertId then hs.alert.closeSpecific(S.alertId); S.alertId = nil end

  local e = S.list[S.idx]
  if not e or not e.win then return end

  -- Focusing an off-space window switches spaces on its own; no gotoSpace
  -- needed, and no Mission Control animation.
  local ok = pcall(function() e.win:focus() end)
  if ok then
    -- Re-touch shortly after so the title refreshes now that it is readable.
    hs.timer.doAfter(0.35, function() touch(e.win) end)
  else
    cache[e.id] = nil
  end
end

local function step(delta)
  if S.active and not hs.eventtap.checkKeyboardModifiers()[M.mods[1]] then
    cancel()   -- stale session from a dropped release; start fresh
  end
  if not S.active then
    S.list = ordered()
    if #S.list == 0 then return end
    S.idx    = 1
    S.active = true
    S.tap:start()
  end
  S.idx = ((S.idx - 1 + delta) % #S.list) + 1
  render()
end

local function cancel()
  if not S.active then return end
  S.active = false
  if S.tap then S.tap:stop() end
  if S.alertId then hs.alert.closeSpecific(S.alertId); S.alertId = nil end
end

--------------------------------------------------------------------------
-- wiring
--------------------------------------------------------------------------

function M.start()
  seed()

  M.wf = hs.window.filter.new()
  M.wf:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowFocused,
    hs.window.filter.windowTitleChanged,
    hs.window.filter.windowUnminimized,
  }, function(w) touch(w) end)

  M.wf:subscribe(hs.window.filter.windowDestroyed, function(w)
    local id = w and safe(w, function(x) return x:id() end)
    if id then cache[id] = nil end
  end)

  -- Every space visit is a chance to learn windows we could not otherwise see.
  M.spaceWatcher = hs.spaces.watcher.new(function()
    hs.timer.doAfter(0.25, seed)
  end)
  M.spaceWatcher:start()

  -- Commit when the modifier is released, not on each keypress.
  S.tap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(ev)
    print("TAP FIRED", hs.inspect(ev:getFlags()), "active:", S.active)
    if S.active and not ev:getFlags()[M.mods[1]] then
      finish()
    end
    return false
  end)

  S.escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
    if S.active and ev:getKeyCode() == hs.keycodes.map.escape then
      cancel()
      return true   -- swallow it so escape doesn't reach the app
    end
    return false
  end)

  local fwd  = function() step(1) end
  local back = function() step(-1) end
  M.hkNext = hs.hotkey.bind(M.mods, M.nextKey, fwd, nil, fwd)
  M.hkPrev = hs.hotkey.bind(M.mods, M.prevKey, back, nil, back)

  return M
end

return M
