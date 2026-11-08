-- ~/.hammerspoon/init.lua — loader only. No bindings live here.
--
-- Bindings:  config/keymap.lua
-- Mechanism: modules/fnlayer.lua
--
-- This file is a SYMLINK to <repo>/hammerspoon/init.lua (see bootstrap.sh).
--
-- Manual System Settings steps this config depends on (README.md, step 3):
--   1. Keyboard → Modifier Keys → Caps Lock = fn/Globe, set PER KEYBOARD
--   2. Keyboard → "Press 🌐 key to" → Do Nothing        (Escape depends on this)
--   3. Keyboard Shortcuts → Input Sources → "Select next source in Input menu"
--      = ⌃⌥⇧⌘Space, and the "previous source" row CLEARED, not just unchecked

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

-- Watcher before any module loads: if one errors, the rest of this file
-- never runs, and a fix should still reload without a trip to the menu.
configWatcher = hs.pathwatcher.new(root, function(paths)
  for _, p in ipairs(paths) do
    if p:sub(-4) == ".lua" then hs.reload() return end
  end
end)
configWatcher:start()

-- Diagnostics first, so every module's load-time warnings reach .live/log.txt.
-- .live/ sits at the repo root, outside the watched directory, so writing it
-- cannot trigger a reload. Gitignored. See modules/diag.lua.
local diag = require("modules.diag")
diag.setup(root .. "/../.live")
diag.logger("init").i("loading, watching %s", root)

local keymap  = require("config.keymap")
local fnlayer = require("modules.fnlayer")

fnlayer.start(keymap.fn)
require("modules.wincycle").start(keymap.wincycle)
require("modules.citrixfocus").start(keymap.citrixfocus)
require("modules.citrixsignin").start(keymap.citrixsignin)

-- Optional, gitignored probe (probes/README.md). Caught, so a broken probe
-- cannot take the config down with it.
local probe
local probePath = root .. "/probes/active.lua"
if hs.fs.attributes(probePath) then
  local ok, res = xpcall(dofile, debug.traceback, probePath)
  if ok then probe = res else diag.logger("probe").e("load failed: %s", res) end
end

-- hammerspoon://reload, ://status, ://probe. Parameterless endpoints in
-- place of hs.ipc (hammerspoon/DESIGN.md, Decision log). Started last so the load-time status sees
-- every module's provider.
require("modules.urlctl").start({ root = root, probe = probe })

-- A transient alert, not a notification: reloads are frequent, and persistent
-- notifications would pile up. The watched path is in .live/status.json.
hs.alert.show("Hammerspoon config loaded", 1.2)
