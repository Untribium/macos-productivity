# CLAUDE.md

Keyboard-driven macOS productivity setup, without admin rights. Mostly used by
one person, across several machines (home, work). Read the component's
`DESIGN.md` before changing it; if something isn't written down there, it
isn't decided.

## Map

| Path | What | Design doc |
|---|---|---|
| `docs/keymap.md` | **Shared contract:** layer ownership, keybinding namespace, keymap | itself |
| `hammerspoon/` | fn nav layer, window cycling, Citrix helpers (Lua, live via symlinks) | `hammerspoon/DESIGN.md` |
| `overlay/` | Spotlight-style overlay framework + spike app (Swift) | `overlay/DESIGN.md` |
| `todo/` | work todo app on `OverlayKit` (design stage) | `todo/DESIGN.md` |
| `docs/verification/` | probe results, one dated file per probe (template in its README) | |
| `docs/attic/` | retired code kept for its learnings, never loaded | |
| `README.md` | per-machine install, including the manual System Settings steps | |

## Rules

- **Bindings:** check `docs/keymap.md` for a collision and the "do not take"
  rows first. A binding change is one commit: `hammerspoon/config/keymap.lua`
  plus the Keymap row, plus a decision-log entry if it is a real choice.
- **Exactly one event tap watches fn:** `hammerspoon/modules/fnlayer.lua`.
  Other components get caps bindings by having it re-emit a hyper chord.
- **Decisions** go into the owning component's `DESIGN.md` decision log, which
  is append-only. A new tool must claim a layer in `docs/keymap.md`.
- **`hammerspoon/` is the live config** on any machine that ran
  `bootstrap.sh`: saving a file there reloads Hammerspoon immediately.
- **Probes** that need the running Mac: Lua in `hammerspoon/probes/active.lua`
  (gitignored; contract in `probes/README.md`), or shell commands the user runs.
  Output goes to `docs/verification/`, verbatim. Delete `active.lua` after.
- **Never move the user's screen unannounced:** a space switch, `focus()`, app
  launch or quit, or showing a panel. Say what will happen, then wait for a go.
  Probes that only read state need no warning.
- **In chat replies,** never write a lone backtick in prose: the terminal
  renders Markdown and pairs them up. Use `` cmd+` `` spans or \` escapes.

## Tooling (native session on the Mac)

- Hammerspoon has no `hs.ipc`. Drive it with `open -g hammerspoon://reload`,
  `://status`, `://probe`; read `.live/status.json`, `.live/log.txt`,
  `.live/console.txt`.
- `log` is a zsh builtin: use `/usr/bin/log`. The overlay spike logs under
  subsystem `overlay-spike`.
- Overlay: `overlay/scripts/build-app.sh --install`; per-machine environment
  check: `overlay/probes/env-check.sh`.
- No Screen Recording permission for the terminal, so no screenshots; ask the
  user to look or paste one.
- VS Code opens this repo in its "Arduino" profile; install extensions there
  (`--profile Arduino`).
- A Cowork session sees only this folder, from a Linux VM: anything needing
  macOS becomes a command block for the user to run.
