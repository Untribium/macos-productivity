# macos-productivity

Keyboard-driven macOS, without admin rights:

- **`hammerspoon/`**: caps lock as a nav layer (Escape on tap, `caps+hjkl`
  arrows), window cycling across spaces, small app workarounds. Hammerspoon
  owns everything above the key-remapping layer; caps lock is remapped to fn
  by macOS itself.
- **`overlay/`**: a Spotlight-style overlay framework in Swift, and apps on it.

**`docs/keymap.md` is the keyboard contract** all of them share: which tool
owns which layer, the reserved modifier combinations, and every binding. Each
component's goals, open questions and decision log are in its `DESIGN.md`.
This file is only the install procedure.

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
needed — see `hammerspoon/DESIGN.md`, Open questions.)*

### 3. The manual System Settings steps

**These are manual for now.** Automating them is an open item
(`docs/backlog.md` › macOS defaults module). They are per-machine, and step 1
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
   not enough, a disabled row still swallows the chord. See
   `hammerspoon/DESIGN.md`, Open questions, for how to clear it properly via
   `defaults`.

### 4. Verify

- `caps+h/j/k/l` → arrows, on **both** keyboards
- tap `caps` alone → Escape (try it in vim)
- `caps+space` → cycles input source
- edit a comment in `hammerspoon/config/keymap.lua` → Hammerspoon reloads
- a brief "Hammerspoon config loaded" alert appears on each reload
- `.live/status.json` → `watching` names the directory being watched: it must
  be the **repo** path, not `~/.hammerspoon`

### 5. Overlay (optional)

Needs the Command Line Tools (`xcode-select --install`), no Xcode, no admin.

```sh
overlay/probes/env-check.sh             # once: can this machine build and run it?
overlay/scripts/build-app.sh --install  # build, copy to ~/Applications, launch
```

`caps+Return` toggles it. See `overlay/README.md` for the checklist.

## Editing

Add or change a binding = a two-file edit, one commit:

1. `hammerspoon/config/keymap.lua` — the binding
2. `docs/keymap.md` — the Keymap row, plus a decision-log entry in the owning
   component's `DESIGN.md` if it is a real choice

Check the Keymap for a collision **before** proposing anything, and check the
"do not take" rows in the namespace.

After editing, check the Hammerspoon console — `compile()` warns and skips a bad
spec rather than aborting, so a skipped binding looks exactly like a broken one.

Working on this with Claude: see `CLAUDE.md`.
