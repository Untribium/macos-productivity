-- modules/wincycle.lua — cmd+` across spaces: cycle the frontmost app's
-- windows, MRU, on every space and display (SETUP.md §7 "Window cycling
-- across spaces", §8 2026-10-25). PROOF OF CONCEPT.
--
-- Why a cache: no API lists an app's windows on other spaces (AppKit
-- space-filters kAXWindows). But a handle seen once keeps working off-space,
-- and focus() on it switches to its space. So windows are cached as they
-- become reachable, from three sources:
--   1. a window filter: windows on visible spaces, plus each app's
--      focused/main window, which AppKit reports on any space
--   2. a space watcher: everything visible after each space change
--   3. per-app AX observers (added when an app is first activated):
--      AXTitleChanged etc. hand over off-space windows whenever they change
--
-- Liveness: hs.spaces.windowSpaces(id) is empty for a closed window, and the
-- window filter misses off-space closes, so entries are pruned on every press.
-- An entry is admitted only once it has a space (new windows briefly have
-- none).
--
-- Cycling: holding cmd and pressing the key steps through an MRU snapshot,
-- focusing as it goes. MRU is only updated when cmd is released, detected by
-- polling the modifiers while a cycle is open. That avoids a flagsChanged
-- event tap (SETUP.md §8: one tap owns fn).

local diag = require("modules.diag")
local log  = diag.logger("wincycle")

local M = {}

local cache = {}   -- id -> { win, pid, app, seen }
local seq   = 0    -- monotonic MRU counter
local cycle = nil  -- { list, idx, pid, poll } while cmd is held

local function now() seq = seq + 1; return seq end

local function safe(fn, ...)
  local ok, v = pcall(fn, ...)
  if ok then return v end
end

local function spacesOf(id) return hs.spaces.windowSpaces(id) or {} end

-- Admit or refresh a window. `focused` bumps it to the front of MRU.
local function touch(win, focused)
  if not win then return end
  local id = safe(win.id, win)
  if not id then return end
  local e = cache[id]
  if not e then
    if safe(win.isStandard, win) ~= true then return end
    if #spacesOf(id) == 0 then return end         -- not ordered in yet, or gone
    local app = safe(win.application, win)
    local pid = app and safe(app.pid, app)
    if not pid then return end
    e = { win = win, pid = pid, app = safe(app.name, app) or "?", seen = 0 }
    cache[id] = e
  end
  if focused and not cycle then e.seen = now() end
end

local function prune()
  for id in pairs(cache) do
    if #spacesOf(id) == 0 then cache[id] = nil end
  end
end

---------------------------------------------------------------------------
-- sources
---------------------------------------------------------------------------

local function seedVisible()
  for _, w in ipairs(hs.window.allWindows()) do touch(w) end
end

local OBSERVED = { "AXTitleChanged", "AXWindowCreated",
                   "AXFocusedWindowChanged", "AXMainWindowChanged" }
local observers = {}   -- pid -> hs.axuielement.observer

local function windowOf(el)
  if safe(el.attributeValue, el, "AXRole") == "AXWindow" then return el end
  return safe(el.attributeValue, el, "AXWindow")
end

local function observe(app)
  local pid = app and safe(app.pid, app)
  if not pid or observers[pid] then return end
  local obs = safe(hs.axuielement.observer.new, pid)
  local appEl = safe(hs.axuielement.applicationElement, app)
  if not (obs and appEl) then return end
  obs:callback(function(_, el)
    local wel = windowOf(el)
    local win = wel and safe(wel.asHSWindow, wel)
    if win then touch(win) end
  end)
  for _, n in ipairs(OBSERVED) do pcall(obs.addWatcher, obs, appEl, n) end
  obs:start()
  observers[pid] = obs
  log.d("observing %s (%d)", safe(app.name, app) or "?", pid)
end

---------------------------------------------------------------------------
-- cycling
---------------------------------------------------------------------------

local function endCycle()
  if not cycle then return end
  if cycle.poll then cycle.poll:stop() end
  local e = cycle.list[cycle.idx]
  cycle = nil
  if e then e.seen = now() end   -- commit: the landed-on window becomes MRU
end

local function startCycle(app, focusedId)
  prune()
  local pid = app:pid()
  -- make sure the app's own reachable windows are in, before snapshotting
  for _, w in ipairs(app:allWindows()) do touch(w) end
  touch(app:focusedWindow()); touch(app:mainWindow())

  local list = {}
  for id, e in pairs(cache) do
    if e.pid == pid and safe(e.win.isMinimized, e.win) ~= true then list[#list + 1] = e end
  end
  -- the focused window goes first regardless of its counter
  table.sort(list, function(a, b)
    local af, bf = a.win:id() == focusedId, b.win:id() == focusedId
    if af ~= bf then return af end
    return a.seen > b.seen
  end)
  if #list < 2 then return log.i("%s: %d window(s) known, nothing to cycle", app:name(), #list) end

  cycle = { list = list, idx = 1, pid = pid }
  cycle.poll = hs.timer.doEvery(0.05, function()
    if not hs.eventtap.checkKeyboardModifiers().cmd then endCycle() end
  end)
  return true
end

local function ms(t0) return (hs.timer.absoluteTime() - t0) / 1e6 end

local function step(delta)
  local t0 = hs.timer.absoluteTime()
  local app = hs.application.frontmostApplication()
  if not app then return end
  if cycle and cycle.pid ~= app:pid() then endCycle() end
  local tSnap = 0
  if not cycle then
    local fw = hs.window.focusedWindow()
    if not startCycle(app, fw and fw:id()) then return end
    tSnap = ms(t0)
  end
  local tFocus0 = hs.timer.absoluteTime()
  local n = #cycle.list
  for _ = 1, n do                       -- skip entries that died mid-cycle
    cycle.idx = ((cycle.idx - 1 + delta) % n) + 1
    local e = cycle.list[cycle.idx]
    local id = safe(e.win.id, e.win)
    if id and #spacesOf(id) > 0 and pcall(e.win.focus, e.win) then
      log.i("%s → %d (%d/%d) on space %s  [snapshot %.0fms, focus %.0fms, total %.0fms]",
            e.app, id, cycle.idx, n, hs.inspect(spacesOf(id)), tSnap, ms(tFocus0), ms(t0))
      return
    end
    if id then cache[id] = nil end
  end
  endCycle()
end

---------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------

-- spec: { mods = {"cmd"}, keycodes = { 50 } } from config/keymap.lua
function M.start(spec)
  M.wf = hs.window.filter.new(false):setDefaultFilter({})
  M.wf:subscribe(hs.window.filter.windowFocused, function(w) touch(w, true) end)
  M.wf:subscribe({ hs.window.filter.windowCreated, hs.window.filter.windowVisible,
                   hs.window.filter.windowTitleChanged }, function(w) touch(w) end)
  for _, w in ipairs(M.wf:getWindows()) do touch(w) end

  M.spaceWatcher = hs.spaces.watcher.new(function()
    M.settle = hs.timer.doAfter(0.3, seedVisible)
  end)
  M.spaceWatcher:start()

  M.appWatcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.activated then observe(app) end
  end)
  M.appWatcher:start()
  observe(hs.application.frontmostApplication())

  M.hotkeys = {}
  for _, kc in ipairs(spec.keycodes) do
    local fwd, back = function() step(1) end, function() step(-1) end
    M.hotkeys[#M.hotkeys + 1] = hs.hotkey.bind(spec.mods, kc, fwd, nil, fwd)
    local rev = { "shift" }
    for _, m in ipairs(spec.mods) do rev[#rev + 1] = m end
    M.hotkeys[#M.hotkeys + 1] = hs.hotkey.bind(rev, kc, back, nil, back)
  end

  diag.provide("wincycle", function()
    local byApp = {}
    for id, e in pairs(cache) do
      byApp[e.app] = byApp[e.app] or {}
      table.insert(byApp[e.app], { id = id, seen = e.seen, spaces = spacesOf(id),
                                   title = (safe(e.win.title, e.win) or ""):sub(1, 40) })
    end
    for _, l in pairs(byApp) do table.sort(l, function(a, b) return a.seen > b.seen end) end
    local obs = {}
    for pid in pairs(observers) do obs[#obs + 1] = pid end
    return { windows = byApp, observedPids = obs, cycling = cycle ~= nil }
  end)

  seedVisible()
  log.i("started: keycodes %s, %d windows cached", hs.inspect(spec.keycodes),
        (function() local n = 0 for _ in pairs(cache) do n = n + 1 end return n end)())
  return M
end

return M
