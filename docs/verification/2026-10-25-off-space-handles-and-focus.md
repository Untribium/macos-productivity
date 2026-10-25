# Captured window handles off-space, and focus() across spaces (macOS 27.0.1)

- **Date:** 2026-10-25
- **Question:** findings 2 and 5 in `docs/attic/README.md`. Does a handle
  captured while its space is visible stay usable off-space? Does `focus()` on
  an off-space handle switch to its space?
- **Machine:** macOS 27.0.1, Hammerspoon 1.1.1, one screen, built-in keyboard.
  Reduce Motion **on** (`com.apple.universalaccess reduceMotion = 1`).

Setup: desktop "1" (space id 6) held two Chrome windows (3736 regular, 23683
incognito) and Claude (23759). Desktop "8" (id 234) held Code and Terminal.
Probe: `hammerspoon/probes/active.lua` captured every standard window from
`hs.window.allWindows()` 0.5s after each space change. Steps ran through
`hammerspoon://probe` with no reload, so the captured handles survived.

## Command

1. Probe loaded on 234 and captured Code and Terminal. The user switched to
   desktop 1, waited, and came back. The probe captured 3 windows on 6.
2. `read` step from 234: every field on every captured handle.
3. `focus` step from 234: `focus()` on the captured Chrome window that is not
   `chrome:mainWindow()`, then after 1.5s read `focusedSpace()` and
   `focusedWindow()`. Run four times, alternating targets.
4. `raise` step from 234: `raise()` on the non-main Chrome window, no focus.
   `raisefocus`: `raise()` then `focus()`. Run twice.
5. Control by the user: switching with ⌃1, the native shortcut.

## Output

```
capture (load) on space 234: 2 new
capture (space change) on space 6: 3 new
capture (space change) on space 234: 0 new
read: 5 captured handles, from space 234
  23683 Google Chrome  "<incognito search>"   frame [0,33,1512,949]  spaces [6]  standard  visible
  23759 Claude         "Claude"               frame [0,33,1512,949]  spaces [6]  standard  visible
   3736 Google Chrome  "Sign in successful…"  frame [0,33,1512,949]  spaces [6]  standard  visible
  (+ Code 24036, Terminal 20836 on [234])

focus: called on 23683 (main was 3736), ok=true  → now on space 6, focused window 23683
focus: called on 3736 (main was 23683), ok=true  → now on space 6, focused window 3736
focus: called on 23683 (main was 3736), ok=true  → now on space 6, focused window 23683
focus: called on 3736 (main was 23683), ok=true  → now on space 6, focused window 3736

raise: on 3736 (main was 23683) from space 234, ok=true → after 0.5s main=3736, space=234
raisefocus: on 23683 (main was 3736) from 234 → after 1.5s space=6 focused=23683
raisefocus: on 3736 (main was 23683) from 234 → after 1.5s space=6 focused=3736
```

The incognito title is redacted. `isMinimized` showed `ERR false` because of a
probe bug (`ok and v or …` falls through on `false`); none were minimized.

User observation: the switch is a crossfade, not a slide, which is consistent
with Reduce Motion. The correct window was in front every time. There is a
very brief flicker, the same with or without the early `raise()`, and the
same when switching with ⌃1. So it belongs to the space switch, not to
Hammerspoon.

## Conclusion

- **Finding 2 holds.** A handle captured while its space was visible is fully
  usable from another space: id, title, app, frame, `windowSpaces`. That
  includes the second Chrome window, which no API could discover from 234
  (see `2026-10-25-window-discovery-off-space.md`).
- **Finding 5 holds.** `focus()` on an off-space handle switches to that space
  and brings that exact window to the front, whichever of the app's windows
  was main before. No `gotoSpace` call is needed.
- **`raise()` works off-space without switching**: it changed Chrome's main
  window while the user stayed on 234. It made no visible difference to the
  switch, so `focus()` alone is enough. Keep `raise()` in mind for reordering
  without switching.
- **The flicker is macOS's**, with Reduce Motion on. It cannot be avoided and
  is not a blocker.
- Still open: whether ids are reused (finding 4). Modifier release (finding 6)
  no longer applies to the cmd+` target (§7).
