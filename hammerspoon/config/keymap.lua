-- config/keymap.lua — bindings as data. This is the file you edit.
-- Machine-readable counterpart to SETUP.md §5. Keep them in sync.

local HYPER = { "ctrl", "alt", "cmd", "shift" }  -- private channel to OS shortcuts

-- Spec shape:
--   key         (required unless action) destination key name, e.g. "left"
--   mods        (optional) modifiers to ADD to the replacement. default {}
--   passthrough (optional) default true.
--                 true  → mods are merged with whatever you were holding,
--                         so caps+shift+<k> and caps+alt+<k> work for free
--                 false → mods REPLACE what you were holding. use for chords
--                         addressed at the OS rather than at the focused app
--   action      (optional) a function, called on keyDown. use when the result
--                 is not a keystroke — e.g. window ops. excludes `key`
--
-- Never put "fn" in mods. The replacement must not re-enter the tap.

return {
  fn = {
    -- nav cluster — §5, decided and verified
    h     = { key = "left"  },
    j     = { key = "down"  },
    k     = { key = "up"    },
    l     = { key = "right" },

    -- input source cycle — re-emits the chord the OS shortcut sits on.
    -- passthrough=false: the OS shortcut wants exactly hyper+space, not
    -- hyper+whatever-else-you-were-holding. No layout list lives here.
    space = { key = "space", mods = HYPER, passthrough = false },

    -- overlay toggle — re-emits hyper+Return, which the overlay app registers
    -- as a Carbon hotkey (overlay/, SPIKE). Same pattern as space above.
    -- The source is padenter, not return: macOS turns fn+Return into keypad
    -- Enter (76) before the tap sees it (probe, 2026-11-08).
    padenter = { key = "return", mods = HYPER, passthrough = false },

    -- PROPOSED, NOT DECIDED — §7. Uncomment only once a §5 row exists.
    -- u = { key = "pageup"  },
    -- d = { key = "pagedown" },
    -- a = { key = "left",  mods = { "cmd" } },
    -- e = { key = "right", mods = { "cmd" } },
  },

  -- cmd + key left of 1: cycle the frontmost app's windows across spaces, MRU
  -- (§4, §5, modules/wincycle.lua). cmd+shift reverses. Keycodes, not
  -- characters, so switching input layout does not move it. 50 is that key
  -- on ANSI hardware (personal built-in), 10 on ISO (work laptop, CH).
  -- Both are bound until per-machine config exists (SETUP.md §7); on ISO,
  -- 50 is another physical key, so watch for a stray binding there.
  -- overlay = false gives a plain toggle/cycle with no list (switch on release
  -- either way). The overlay shows on the 2nd press, or after overlayDelay s held.
  wincycle = { mods = { "cmd" }, keycodes = { 50, 10 }, overlay = true, overlayDelay = 0.3 },

  -- Not a binding: Citrix Viewer workaround (modules/citrixfocus.lua). On
  -- activation, a mouse move clears keyboard focus from the hidden toolbar
  -- notch. restoreCursor = false if focus returns to the notch.
  citrixfocus = { enabled = true, appName = "Citrix Viewer", delay = 0.15, restoreCursor = true, restoreDelay = 0.05 },

  -- Not a binding: types the email from config/local.lua (citrixEmail) and
  -- presses Return when the sign-in window gains focus, once per window
  -- (modules/citrixsignin.lua).
  citrixsignin = { enabled = true, appName = "Citrix Workspace Authentication", titleMatch = "Sign in", delay = 0.5 },
}
