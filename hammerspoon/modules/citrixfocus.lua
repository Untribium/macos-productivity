-- modules/citrixfocus.lua — clear the Citrix Viewer toolbar-notch focus.
--
-- Bug (Citrix Workspace 2609, macOS): switching to the Citrix Viewer desktop
-- session leaves keyboard focus on the hidden Desktop Viewer toolbar notch
-- (red focus ring), so Space opens the toolbar. Esc is no way out: the Esc
-- emulation does not work inside Citrix. The "Use Toolbar shortcut" toggle
-- only affects the shortcut; removing the toolbar needs server-side
-- StoreFront config (CTX585673). Untested: turning off macOS Keyboard
-- navigation / Full Keyboard Access.
--
-- Workaround: a mouse move over the Citrix window clears the focus, but only
-- with the cursor over the window, and only a real mouseMoved event counts
-- (hs.mouse.absolutePosition warps are not detected). On activation:
--   * skip if a mouse button is held (a drag or click is in progress)
--   * cursor already inside the window: nudge it 1 px in place
--   * otherwise post mouseMoved to the window centre, then centre+1 px
--   * optionally warp the cursor back to where it was (restoreCursor)
--
-- The watcher lives in a module-level variable so it is not garbage collected.

local diag = require("modules.diag")
local log  = diag.logger("citrixfocus")

local M = {}

local watcher

-- Tried and failed: post(app) to deliver the move to Citrix only, without
-- moving the real cursor. Citrix ignores it; the pointer must really move.
local function move(pt)
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, pt):post()
end

local function inside(pt, f)
  return pt.x >= f.x and pt.x < f.x + f.w and pt.y >= f.y and pt.y < f.y + f.h
end

local function fix(cfg, app)
  if next(hs.eventtap.checkMouseButtons()) then   -- table of held buttons
    log.i("mouse button held, skipped")
    return
  end
  local win = app:mainWindow() or app:focusedWindow()
  if not win then log.w("no window") return end
  local f    = win:frame()
  local orig = hs.mouse.absolutePosition()

  if inside(orig, f) then
    log.d("cursor inside %s, nudge", hs.inspect(f))
    move({ x = orig.x + 1, y = orig.y })
    move(orig)
    return
  end

  local c = { x = f.x + f.w / 2, y = f.y + f.h / 2 }
  log.d("cursor %s outside %s, move to centre", hs.inspect(orig), hs.inspect(f))
  move(c)
  move({ x = c.x + 1, y = c.y })
  if cfg.restoreCursor then
    -- Posted events reach the window server asynchronously; warping back
    -- immediately can land BEFORE them, leaving the cursor at the centre.
    hs.timer.doAfter(cfg.restoreDelay or 0.05, function()
      hs.mouse.absolutePosition(orig)
    end)
  end
end

-- cfg: { appName, delay, restoreCursor }. enabled = false turns it off.
function M.start(cfg)
  cfg = cfg or {}
  if cfg.enabled == false then return end
  local name  = cfg.appName or "Citrix Viewer"
  local delay = cfg.delay or 0.15

  if watcher then watcher:stop() end
  watcher = hs.application.watcher.new(function(appName, event, app)
    if event == hs.application.watcher.activated and appName == name then
      hs.timer.doAfter(delay, function()
        local ok, err = pcall(fix, cfg, app)
        if not ok then log.e("fix failed: %s", err) end
      end)
    end
  end)
  watcher:start()
  log.i("watching activation of %s", name)
end

return M
