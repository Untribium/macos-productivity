-- modules/fnlayer.lua — sole owner of the fn/Globe event tap (SETUP.md §3, layer 1).
--
-- INVARIANT: exactly one event tap may watch the fn flag. Two taps means
-- nondeterministic ordering and double consumption. Anything fn-based
-- registers here via config/keymap.lua. Anything NOT fn-based can use
-- hs.hotkey instead, which needs no tap.

local M = {}

-- Synthetic keyDown macOS emits on a lone, unchorded Globe tap. Undocumented;
-- only emitted while Keyboard → "Press 🌐 key to" is Do Nothing.
local GLOBE_TAP_KEYCODE = 179

local eventTypes = hs.eventtap.event.types
local PASSABLE   = { "cmd", "alt", "ctrl", "shift" }  -- note: fn deliberately absent

-- Modifiers you were actually holding, minus fn. Dropping fn is what stops
-- fn+← becoming Home, and is also the loop guard: the replacement carries no
-- fn, so this tap will not re-match it.
local function stripFn(flags)
  local mods = {}
  for _, m in ipairs(PASSABLE) do
    if flags[m] then table.insert(mods, m) end
  end
  return mods
end

local function merge(a, b)
  local seen, out = {}, {}
  for _, list in ipairs({ a or {}, b or {} }) do
    for _, m in ipairs(list) do
      if not seen[m] then
        seen[m] = true
        table.insert(out, m)
      end
    end
  end
  return out
end

-- Resolve key NAMES to keycodes once at load, and complain loudly about a bad
-- spec rather than silently doing nothing at 3pm on a Tuesday.
local function compile(keymap)
  local byKeycode = {}
  for name, spec in pairs(keymap) do
    local kc = hs.keycodes.map[name]
    if not kc then
      hs.printf("fnlayer: unknown source key %q — binding skipped", name)
    elseif not (spec.key or spec.action) then
      hs.printf("fnlayer: %q has neither key nor action — skipped", name)
    elseif spec.key and not hs.keycodes.map[spec.key] then
      hs.printf("fnlayer: %q → unknown destination key %q — skipped",
                name, spec.key)
    else
      for _, m in ipairs(spec.mods or {}) do
        if m == "fn" then
          error(("fnlayer: %q has fn in mods — would loop"):format(name))
        end
      end
      byKeycode[kc] = spec
    end
  end
  return byKeycode
end

function M.start(keymap)
  if M.tap then M.tap:stop() end
  local bindings = compile(keymap)

  M.tap = hs.eventtap.new(
    { eventTypes.keyDown, eventTypes.keyUp },
    function(e)
      local kc    = e:getKeyCode()
      local flags = e:getFlags()
      local down  = (e:getType() == eventTypes.keyDown)

      -- Lone tap → Escape. Stays in mechanism rather than the keymap: 179
      -- arrives as a keyDown with no matching keyUp, so it cannot use the
      -- replacement-event path below and needs keyStroke to synthesize both.
      if kc == GLOBE_TAP_KEYCODE then
        if down then hs.eventtap.keyStroke({}, "escape", 0) end
        return true
      end

      if not flags.fn then return false end
      local spec = bindings[kc]
      if not spec then return false end

      if spec.action then
        if down then spec.action() end
        return true
      end

      local mods
      if spec.passthrough == false then
        mods = spec.mods or {}
      else
        mods = merge(spec.mods, stripFn(flags))
      end

      -- Delete the original, post a replacement. Handling keyUp identically
      -- means apps never see an unmatched keyDown, and OS autorepeat drives
      -- repeat for free.
      return true, { hs.eventtap.event.newKeyEvent(mods, spec.key, down) }
    end
  )
  M.tap:start()

  -- macOS disables taps under load, after timeouts, and across sleep.
  if M.watchdog then M.watchdog:stop() end
  M.watchdog = hs.timer.doEvery(5, function()
    if M.tap and not M.tap:isEnabled() then
      print("fnlayer: tap disabled — restarting")
      M.tap:start()
    end
  end)

  if M.wakeWatcher then M.wakeWatcher:stop() end
  M.wakeWatcher = hs.caffeinate.watcher.new(function(evt)
    if evt == hs.caffeinate.watcher.systemDidWake
      or evt == hs.caffeinate.watcher.screensDidUnlock then
      if M.tap and not M.tap:isEnabled() then M.tap:start() end
    end
  end)
  M.wakeWatcher:start()
end

function M.stop()
  if M.tap then M.tap:stop() end
  if M.watchdog then M.watchdog:stop() end
  if M.wakeWatcher then M.wakeWatcher:stop() end
end

return M
