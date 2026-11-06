-- modules/citrixsignin.lua — type the email into the Citrix Workspace sign-in
-- window and press Return, once per window, when it gains focus.
--
-- The email is read from config/local.lua (gitignored): return { citrixEmail = "..." }.
-- Typing goes to whatever has focus, so the window is re-checked right before
-- each keystroke and the run is abandoned if focus moved.

local diag = require("modules.diag")
local log  = diag.logger("citrixsignin")

local M = {}

local filter
local done = {}   -- window ids already handled; cleared when the window closes

local function email()
  local ok, loc = pcall(require, "config.local")
  return ok and type(loc) == "table" and loc.citrixEmail or nil
end

local function isFront(win)
  local f = hs.window.frontmostWindow()
  return f and f:id() == win:id()
end

local function signIn(cfg, win)
  local addr = email()
  if not addr then log.w("no citrixEmail in config/local.lua, skipped") return end
  if cfg.titleMatch and not (win:title() or ""):find(cfg.titleMatch) then
    log.d("title %q does not match, skipped", win:title())
    return
  end
  if done[win:id()] then return end
  done[win:id()] = true

  hs.timer.doAfter(cfg.delay or 0.5, function()
    if not isFront(win) then log.w("window lost focus, not typing") return end
    hs.eventtap.keyStrokes(addr)
    hs.timer.doAfter(0.2, function()
      if not isFront(win) then log.w("window lost focus, no return") return end
      hs.eventtap.keyStroke({}, "return")
      log.i("typed email and pressed return")
    end)
  end)
end

-- cfg: { appName, titleMatch, delay }. enabled = false turns it off.
function M.start(cfg)
  cfg = cfg or {}
  if cfg.enabled == false then return end
  local name = cfg.appName or "Citrix Workspace Authentication"

  if filter then filter:unsubscribeAll() end
  filter = hs.window.filter.new(false):setAppFilter(name, {})
  -- The window is focused before its title is set ("Citrix Workspace", then
  -- "Citrix Workspace — Sign in ..."), so the title change must re-run the check.
  local function onEvent(win)
    local ok, err = pcall(signIn, cfg, win)
    if not ok then log.e("sign-in failed: %s", err) end
  end
  filter:subscribe(hs.window.filter.windowFocused, onEvent)
  filter:subscribe(hs.window.filter.windowTitleChanged, function(win)
    if isFront(win) then onEvent(win) end
  end)
  filter:subscribe(hs.window.filter.windowDestroyed, function(win)
    done[win:id()] = nil
  end)
  log.i("watching focus of %s", name)
end

return M
