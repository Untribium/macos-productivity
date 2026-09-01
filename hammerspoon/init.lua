-- ~/.hammerspoon/init.lua — loader only. No bindings live here.
--
-- Bindings:  config/keymap.lua
-- Mechanism: modules/fnlayer.lua
--
-- This file is a SYMLINK to <repo>/hammerspoon/init.lua (see bootstrap.sh).
--
-- Manual System Settings steps this config depends on (SETUP.md §9):
--   1. Keyboard → Modifier Keys → Caps Lock = fn/Globe, set PER KEYBOARD
--   2. Keyboard → "Press 🌐 key to" → Do Nothing        (Escape depends on this)
--   3. Keyboard Shortcuts → Input Sources → "Select next source in Input menu"
--      = ⌃⌥⇧⌘Space, and the "previous source" row CLEARED, not just unchecked

local keymap  = require("config.keymap")
local fnlayer = require("modules.fnlayer")

fnlayer.start(keymap.fn)

-- Auto-reload on config change.
--
-- hs.configdir is ~/.hammerspoon, whose entries are symlinks into the repo.
-- FSEvents reports on the directory it is given and does NOT see writes that
-- land on a symlink's target, so watching hs.configdir alone would silently
-- stop auto-reloading once bootstrap.sh has run. Resolve this file's own link
-- and watch the repo directory instead; fall back to hs.configdir when the
-- config is a real directory (e.g. before bootstrap, or on a copy install).
local function configRoot()
  local this = debug.getinfo(1, "S").source:sub(2)      -- ~/.hammerspoon/init.lua
  local target = hs.fs.symlinkAttributes(this, "target")
  if target then
    if target:sub(1, 1) ~= "/" then                     -- relative link
      target = hs.configdir .. "/" .. target
    end
    return target:match("^(.*)/[^/]+$")
  end
  return hs.configdir
end

local root = configRoot()
configWatcher = hs.pathwatcher.new(root, function(paths)
  for _, p in ipairs(paths) do
    if p:sub(-4) == ".lua" then hs.reload() return end
  end
end)
configWatcher:start()

hs.notify.show("Hammerspoon", "", "config loaded — " .. root)
