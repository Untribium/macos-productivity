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

    -- PROPOSED, NOT DECIDED — §7. Uncomment only once a §5 row exists.
    -- u = { key = "pageup"  },
    -- d = { key = "pagedown" },
    -- a = { key = "left",  mods = { "cmd" } },
    -- e = { key = "right", mods = { "cmd" } },
  },

  -- cmd + key left of 1: cycle the frontmost app's windows across spaces, MRU
  -- (§4, §5, modules/wincycle.lua). cmd+shift reverses. Keycodes, not
  -- characters, so switching input layout does not move it. 50 is that key
  -- on ANSI hardware (this machine's built-in). ISO hardware (CH) likely
  -- sends 10 there instead: check on the work machine.
  -- overlay = false gives a plain toggle/cycle with no list (switch on release
  -- either way). The overlay shows on the 2nd press, or after overlayDelay s held.
  wincycle = { mods = { "cmd" }, keycodes = { 50 }, overlay = true, overlayDelay = 0.3 },
}
