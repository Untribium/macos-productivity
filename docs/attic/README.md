# attic

Retired code, kept for what it taught. **Nothing here is loaded.** It sits
outside `hammerspoon/`, so it is neither symlinked into `~/.hammerspoon` nor
seen by the auto-reload watcher. Files are verbatim copies of the live config
as it was before `bootstrap.sh` replaced it (2026-10-25).

## `winswitch.lua` — cross-space MRU window switcher (alt+tab)

Was loaded by the pre-repo `init.lua`. Rejected as a design, so it is not in
the repo config, but worth reading before the window-switching subtopic (§6).

What it established:

- **No API lists windows on inactive spaces**, but an `hs.window` handle
  picked up while its space was visible **stays valid off-space**. The
  workaround: cache handles as windows appear (window filter + a re-seed on
  every space change) and reuse them.
- `hs.spaces.windowsForSpace()` *can* list window **ids** across all spaces,
  which is enough to drop dead windows and keep each one's space up to date.
  Window ids are reused after an app restarts, so pruning is required.
- **`win:focus()` on an off-space window switches to its space by itself**,
  with no `gotoSpace` call and no Mission Control animation.
- Committing on modifier release needs a `flagsChanged` tap; a dropped
  release leaves a stale session, so check the live modifiers on each step.

Known defects, if anyone revives it:

- `step()` calls `cancel()` before it is defined. `cancel` is a `local` declared
  further down, so inside `step` it is an unset global and the stale-session
  path errors.
- `S.escTap` is created but never started, so Escape never cancels.
- A debug `print("TAP FIRED", …)` runs on every modifier change while loaded.
- It is a second event tap. It does not watch fn, so it doesn't break the
  single-tap rule in §8, but any future switcher should be checked against that rule.
- `alt+tab` / ``alt+` `` were taken without §4/§5 namespace rows.

## `capsnav.lua` — first nav layer

Superseded by `hammerspoon/modules/fnlayer.lua`, which carries over its
watchdog and wake-restart logic. Kept for history only. It was not loaded by
the pre-repo `init.lua`.
