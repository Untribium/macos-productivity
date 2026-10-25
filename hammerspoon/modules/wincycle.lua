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
-- Cycling works like cmd+tab: each press only SELECTS from an MRU snapshot;
-- releasing cmd focuses the selection, once, and commits it as MRU. A quick
-- tap therefore toggles to the last-used window with no overlay. From the
-- second press, or once cmd has been held for overlayDelay, an overlay lists
-- the windows (title, desktop) and further presses move the highlight. Escape cancels. Release
-- is detected by polling the modifiers every 20 ms while a cycle is open.
-- That avoids a flagsChanged event tap (SETUP.md §8: one tap owns fn).

local diag = require("modules.diag")
local log  = diag.logger("wincycle")

local M = {}

local cache = {}   -- id -> { win, pid, app, seen }
M.cache = cache   -- read-only view, for probes
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
-- cycling: every press selects, releasing cmd switches (like cmd+tab)
---------------------------------------------------------------------------

M.overlayEnabled = true   -- set from spec.overlay
M.overlayDelay   = 0.3    -- set from spec.overlayDelay (seconds)

-- "desktop N" by position in allSpaces() order; display index added when
-- there is more than one display
local function spaceLabel(id)
  local sp = spacesOf(id)[1]
  if not sp then return "?" end
  local screens, label = 0, nil
  for uuid, list in pairs(hs.spaces.allSpaces() or {}) do
    screens = screens + 1
    for i, sid in ipairs(list) do
      if sid == sp then label = { screen = uuid, n = i } end
    end
  end
  if not label then return "?" end
  if screens > 1 then
    for i, scr in ipairs(hs.screen.allScreens()) do
      if scr:getUUID() == label.screen then return ("display %d · desktop %d"):format(i, label.n) end
    end
  end
  return ("desktop %d"):format(label.n)
end

-- Overlay geometry. The canvas is larger than the panel by MARGIN on every
-- side so the panel's shadow has room to fall.
local MARGIN, W, HEAD, ROW_H, PAD, RADIUS = 40, 600, 52, 30, 10, 24
local HL = 3   -- element index of the selection pill (above the sheen); see place()

-- Approximates Liquid Glass: translucent body, top sheen, bright rim. Real glass blurs/refracts what is behind the window;
-- a canvas cannot sample the screen without Screen Recording (not granted).
-- The selection is a flat accent-coloured pill, like a native macOS selection;
-- accent and light/dark are read on every draw, so a settings change shows at once.
local function palette(style)
  if (style or hs.host.interfaceStyle()) == "Dark" then
    return { body = { white = 0.10, alpha = 0.78 }, sheen = { white = 1, alpha = 0.16 },
             rim = { white = 1, alpha = 0.22 },
             text = { white = 1, alpha = 0.96 }, dim = { white = 1, alpha = 0.55 },
             sep = { white = 1, alpha = 0.10 }, shadow = { white = 0, alpha = 0.45 } }
  end
  return { body = { white = 0.97, alpha = 0.82 }, sheen = { white = 1, alpha = 0.60 },
           rim = { white = 1, alpha = 0.75 },
           text = { white = 0, alpha = 0.88 }, dim = { white = 0, alpha = 0.50 },
           sep = { white = 0, alpha = 0.08 }, shadow = { white = 0, alpha = 0.28 } }
end

local CLEAR = { white = 1, alpha = 0 }

-- Text colour for the selected row: white or near-black, whichever has the
-- higher WCAG contrast against the pill. White on blue, dark on light
-- accents such as green or yellow.
local function onAccent(c)
  local function lin(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
  local L = 0.2126 * lin(c.red) + 0.7152 * lin(c.green) + 0.0722 * lin(c.blue)
  local vsWhite, vsBlack = 1.05 / (L + 0.05), (L + 0.05) / 0.05
  if vsWhite >= vsBlack then return { white = 1 }, { white = 1, alpha = 0.85 } end
  return { white = 0, alpha = 0.9 }, { white = 0, alpha = 0.65 }
end

-- rows: { { title = , label = } }, idx: selected row, app: { name, bundleID },
-- frame: the screen frame to centre on. style ("Dark"/"Light") and accent (a
-- colour table) override the system appearance, for previews.
-- Returns canvas, x, y, centreY.
-- Pure drawing, no cycle state, so it can be rendered offscreen to a file.
function M.buildOverlay(rows, idx, app, frame, style, accent)
  local P = palette(style)
  local panelH = HEAD + PAD * 2 + ROW_H * #rows
  local cw, ch = W + 2 * MARGIN, panelH + 2 * MARGIN
  local rowTop = MARGIN + HEAD + PAD
  local centreY = frame.y + frame.h / 2
  local x = frame.x + (frame.w - cw) / 2
  local y = centreY - (rowTop + (idx - 1) * ROW_H + ROW_H / 2)
  local panel = { x = MARGIN, y = MARGIN, w = W, h = panelH }
  local radii = { xRadius = RADIUS, yRadius = RADIUS }

  local c = hs.canvas.new({ x = x, y = y, w = cw, h = ch })
  c[1] = { type = "rectangle", action = "fill", frame = panel, roundedRectRadii = radii,
           fillColor = P.body, withShadow = true,
           shadow = { blurRadius = 36, color = P.shadow, offset = { w = 0, h = -14 } } }
  c[2] = { type = "rectangle", action = "fill", frame = panel, roundedRectRadii = radii,
           fillGradient = "linear", fillGradientAngle = 90,
           fillGradientColors = { CLEAR, CLEAR, P.sheen } }   -- evenly spaced: sheen on the top third
  -- the selection is the system accent colour (System Settings → Appearance),
  -- read on every draw so a change applies at once; flat, no gradient
  accent = accent or hs.drawing.color.lists()["System"]["controlAccentColor"]
  c[HL] = { type = "rectangle", action = "strokeAndFill",
            frame = { x = MARGIN + 8, y = rowTop + (idx - 1) * ROW_H, w = W - 16, h = ROW_H },
            roundedRectRadii = { xRadius = 12, yRadius = 12 },
            fillColor = { red = accent.red, green = accent.green, blue = accent.blue, alpha = 0.85 },
            strokeColor = accent, strokeWidth = 1 }
  local selText, selDim = onAccent(accent)
  c[4] = { type = "rectangle", action = "stroke", roundedRectRadii = radii,
           frame = { x = MARGIN + 0.5, y = MARGIN + 0.5, w = W - 1, h = panelH - 1 },
           strokeColor = P.rim, strokeWidth = 1 }

  local icon = app.bundleID and hs.image.imageFromAppBundle(app.bundleID)
  if icon then
    c[#c + 1] = { type = "image", image = icon, imageScaling = "scaleProportionally",
                  frame = { x = MARGIN + 18, y = MARGIN + 12, w = 30, h = 30 } }
  end
  c[#c + 1] = { type = "text", text = app.name or "?", textFont = ".AppleSystemUIFontDemi",
                textSize = 16, textColor = P.text,
                frame = { x = MARGIN + 58, y = MARGIN + 16, w = W - 200, h = 24 } }
  c[#c + 1] = { type = "text", text = ("%d windows"):format(#rows), textSize = 12,
                textFont = ".AppleSystemUIFont", textColor = P.dim, textAlignment = "right",
                frame = { x = MARGIN + W - 160, y = MARGIN + 19, w = 140, h = 20 } }
  c[#c + 1] = { type = "rectangle", action = "fill", fillColor = P.sep,
                frame = { x = MARGIN + 16, y = MARGIN + HEAD, w = W - 32, h = 1 } }

  for i, r in ipairs(rows) do
    local ry = rowTop + (i - 1) * ROW_H + 6
    local sel = (i == idx)
    c[#c + 1] = { type = "text", text = r.title, textFont = ".AppleSystemUIFont", textSize = 14,
                  textColor = sel and selText or P.text, textLineBreak = "truncateTail",
                  frame = { x = MARGIN + 24, y = ry, w = W - 48 - 150, h = ROW_H - 6 } }
    c[#c + 1] = { type = "text", text = r.label, textFont = ".AppleSystemUIFont", textSize = 12,
                  textColor = sel and selDim or P.dim, textAlignment = "right",
                  frame = { x = MARGIN + W - 24 - 150, y = ry + 1, w = 150, h = ROW_H - 6 } }
  end
  return c, x, y, centreY
end

local function hideOverlay()
  if M.slide then M.slide:stop(); M.slide = nil end
  if M.canvas then M.canvas:delete(); M.canvas = nil end
  M.lastY = nil
  if M.modal then M.modal:exit() end
end

-- The selected row stays at the screen's vertical centre; the list slides
-- underneath it. Animate from the previous position over ~90 ms.
local SLIDE_STEPS, SLIDE_DT = 6, 0.015

-- The pill is re-placed every frame so that, on screen, it stays on the
-- centre line while the rows move under it.
local function place(c, x, y, centreY)
  c:topLeft({ x = x, y = y })
  c[HL].frame = { x = MARGIN + 8, y = centreY - y - ROW_H / 2, w = W - 16, h = ROW_H }
end

local function slideTo(c, x, y, centreY)
  if M.slide then M.slide:stop(); M.slide = nil end
  local from = M.lastY or y
  M.lastY = y
  if from == y then return place(c, x, y, centreY) end
  local i = 0
  place(c, x, from, centreY)
  M.slide = hs.timer.doEvery(SLIDE_DT, function()
    i = i + 1
    local t = i / SLIDE_STEPS
    t = 1 - (1 - t) * (1 - t)                     -- ease out
    place(c, x, from + (y - from) * t, centreY)
    if i >= SLIDE_STEPS then M.slide:stop(); M.slide = nil end
  end)
end

local function drawOverlay()
  local rows = {}
  for i, e in ipairs(cycle.list) do
    local title = safe(e.win.title, e.win) or ""
    rows[i] = { title = title ~= "" and title or "(untitled)",
                label = spaceLabel(safe(e.win.id, e.win) or 0) }
  end
  local app = hs.application.applicationForPID(cycle.pid)
  local c, x, y, centreY = M.buildOverlay(rows, cycle.idx,
    { name = app and app:name(), bundleID = app and app:bundleID() },
    hs.screen.mainScreen():frame())
  c:level(hs.canvas.windowLevels.overlay)
  if M.slide then M.slide:stop(); M.slide = nil end
  if M.canvas then M.canvas:delete() end
  M.canvas = c:show()
  slideTo(c, x, y, centreY)
end

-- release (or cancel): focus the selection, skipping entries that died
local function finish(cancelled)
  if not cycle then return end
  local c = cycle
  cycle = nil
  if c.poll then c.poll:stop() end
  if c.delay then c.delay:stop() end
  hideOverlay()
  if cancelled then return log.i("%s: cancelled", c.list[1].app) end
  if c.idx == 1 then return log.i("%s: stayed on current window", c.list[1].app) end
  local n = #c.list
  for k = 0, n - 1 do
    local i = ((c.idx - 1 + k) % n) + 1
    if i == 1 then break end                 -- wrapped back to the current window
    local e = c.list[i]
    local id = safe(e.win.id, e.win)
    if id and #spacesOf(id) > 0 and pcall(e.win.focus, e.win) then
      e.seen = now()   -- commit: the chosen window becomes MRU
      return log.i("%s → %d (%d/%d) %s after %d press(es)", e.app, id, i, n, spaceLabel(id), c.presses)
    end
    if id then cache[id] = nil end
  end
end

local function startCycle(app, focusedId)
  prune()
  local pid = app:pid()
  -- make sure the app's own reachable windows are in, before snapshotting
  for _, w in ipairs(app:allWindows()) do touch(w) end
  touch(app:focusedWindow()); touch(app:mainWindow())

  local list = {}
  for _, e in pairs(cache) do
    if e.pid == pid and safe(e.win.isMinimized, e.win) ~= true then list[#list + 1] = e end
  end
  -- the focused window goes first regardless of its counter
  table.sort(list, function(a, b)
    local af, bf = a.win:id() == focusedId, b.win:id() == focusedId
    if af ~= bf then return af end
    return a.seen > b.seen
  end)
  if #list < 2 then return log.i("%s: %d window(s) known, nothing to cycle", app:name(), #list) end

  cycle = { list = list, idx = 1, pid = pid, presses = 0 }
  cycle.poll = hs.timer.doEvery(0.02, function()
    if not hs.eventtap.checkKeyboardModifiers().cmd then finish(false) end
  end)
  return true
end

local function step(delta)
  local app = hs.application.frontmostApplication()
  if not app then return end
  if cycle and cycle.pid ~= app:pid() then finish(true) end
  if not cycle then
    local fw = hs.window.focusedWindow()
    if not startCycle(app, fw and fw:id()) then return end
  end
  cycle.presses = cycle.presses + 1
  local n = #cycle.list
  cycle.idx = ((cycle.idx - 1 + delta) % n) + 1
  if not M.overlayEnabled then return end
  -- overlay on the second press, or once cmd has been held for overlayDelay;
  -- a quick tap releases first and never sees it
  local function show()
    if not cycle then return end
    drawOverlay()
    if M.modal then M.modal:enter() end
  end
  if cycle.presses >= 2 or M.canvas then
    if cycle.delay then cycle.delay:stop(); cycle.delay = nil end
    show()
  elseif not cycle.delay then
    cycle.delay = hs.timer.doAfter(M.overlayDelay, show)
  end
end

---------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------

-- spec: { mods = {"cmd"}, keycodes = { 50 }, overlay = true } from config/keymap.lua
function M.start(spec)
  M.overlayEnabled = spec.overlay ~= false
  M.overlayDelay   = spec.overlayDelay or M.overlayDelay
  -- Escape cancels while the overlay is up (with or without cmd still held)
  M.modal = hs.hotkey.modal.new()
  M.modal:bind({}, "escape", function() finish(true) end)
  M.modal:bind({ "cmd" }, "escape", function() finish(true) end)
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
