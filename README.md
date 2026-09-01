# macos-productivity

Keyboard-driven window management on macOS, without admin rights.
Hammerspoon owns everything above the key-remapping layer; caps lock is remapped
to fn by macOS itself.

**`SETUP.md` is the source of truth.** Tool choices, layer ownership, the keymap,
the decision log and the open questions all live there. This file is only the
install procedure.

## Install on a new machine

### 1. Link the config

```sh
git clone <this repo> ~/Projects/claude/macos-productivity
cd ~/Projects/claude/macos-productivity
./bootstrap.sh            # dry run — shows what it would do, and any drift
./bootstrap.sh --apply
```

Symlinks `hammerspoon/{init.lua,config,modules}` into `~/.hammerspoon`, backing
up anything already there. `~/.hammerspoon/Spoons/` is left alone.

### 2. Install Hammerspoon and grant Accessibility

System Settings → Privacy & Security → Accessibility → Hammerspoon.
No admin password required. *(Open question: Input Monitoring may also be
needed — see SETUP.md §7.)*

### 3. The manual System Settings steps

**These are not in the repo and cannot be.** They are per-machine, and steps 1
must be repeated for **every keyboard**. Getting any of them wrong makes the
config look broken.

1. **Keyboard → Keyboard Shortcuts → Modifier Keys → Caps Lock = fn / 🌐 Globe.**
   The pane has a per-keyboard selector at the top. Do it for the built-in
   keyboard *and* for the Zeal60. The label differs per keyboard (fn vs 🌐) —
   they are the same modifier.
2. **Keyboard → "Press 🌐 key to" → Do Nothing.**
   Caps-tap→Escape depends on this: macOS only emits the synthetic keycode 179
   while it is set. If this reverts, Escape silently stops working.
3. **Keyboard → Keyboard Shortcuts → Input Sources →**
   "Select next source in Input menu" = `⌃⌥⇧⌘Space`,
   **and clear the "Select the previous input source" row** — unchecking it is
   not enough, a disabled row still swallows the chord. See SETUP.md §7 for how
   to clear it properly via `defaults`.

### 4. Verify

- `caps+h/j/k/l` → arrows, on **both** keyboards
- tap `caps` alone → Escape (try it in vim)
- `caps+space` → cycles input source
- edit a comment in `hammerspoon/config/keymap.lua` → Hammerspoon reloads
- the load notification names the directory being watched: it must be the
  **repo** path, not `~/.hammerspoon`

## Editing

Add or change a binding = a two-file edit, one commit:

1. `hammerspoon/config/keymap.lua` — the binding
2. `SETUP.md` §5 — the row, plus a §8 decision-log entry if it is a real choice

Check §5 for a collision **before** proposing anything, and check the "do not
take" rows in §4.

After editing, check the Hammerspoon console — `compile()` warns and skips a bad
spec rather than aborting, so a skipped binding looks exactly like a broken one.

## Working on this with Claude

A Cowork session sees this folder and nothing else — not `~/.hammerspoon`, not
System Settings, and its shell is a Linux VM, so `defaults` and `hs` are out of
reach. Anything that needs the running Mac becomes a **probe**: a command block
you run, with the output filed in `docs/verification/`. See SETUP.md §0.
