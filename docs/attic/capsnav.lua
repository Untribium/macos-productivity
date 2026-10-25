-- nav.lua — layer 1 nav layer. Returns a module; caller must keep the handle.

local M = {}

local GLOBE_TAP_KEYCODE = 179

local NAV = {
  [hs.keycodes.map.h] = "left",
  [hs.keycodes.map.j] = "down",
  [hs.keycodes.map.k] = "up",
  [hs.keycodes.map.l] = "right",
}

local eventTypes = hs.eventtap.event.types

local function stripFn(flags)
  local mods = {}
  for _, m in ipairs({ "cmd", "alt", "ctrl", "shift" }) do
    if flags[m] then table.insert(mods, m) end
  end
  return mods
end

function M.start()
  M.tap = hs.eventtap.new(
    { eventTypes.keyDown, eventTypes.keyUp },
    function(e)
      local kc    = e:getKeyCode()
      local flags = e:getFlags()
      local down  = (e:getType() == eventTypes.keyDown)

      if kc == GLOBE_TAP_KEYCODE then
        if down then hs.eventtap.keyStroke({}, "escape", 0) end
        return true
      end

      if flags.fn and NAV[kc] then
        local repl = hs.eventtap.event.newKeyEvent(stripFn(flags), NAV[kc], down)
        return true, { repl }
      end

      return false
    end
  )
  M.tap:start()

  M.watchdog = hs.timer.doEvery(5, function()
    if not M.tap:isEnabled() then
      print("navTap disabled — restarting")
      M.tap:start()
    end
  end)

  M.wake = hs.caffeinate.watcher.new(function(evt)
    if evt == hs.caffeinate.watcher.systemDidWake
      or evt == hs.caffeinate.watcher.screensDidUnlock then
      if not M.tap:isEnabled() then M.tap:start() end
    end
  end)
  M.wake:start()

  return M
end

function M.stop()
  if M.tap then M.tap:stop() end
  if M.watchdog then M.watchdog:stop() end
  if M.wake then M.wake:stop() end
end

return M
