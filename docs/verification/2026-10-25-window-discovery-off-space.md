# What can discover windows on other spaces (macOS 27.0.1)

- **Date:** 2026-10-25
- **Question:** finding 1 in `docs/attic/README.md`, "no API lists windows on
  inactive spaces", re-checked from first principles for the window switcher
- **Machine:** macOS 27.0.1, Hammerspoon 1.1.1, one screen

Run by Claude Code through `hammerspoon/probes/active.lua` (a probe runner;
see `hammerspoon/probes/README.md`), from desktop "8" (space id 234). Desktop
"1" (space id 6) held two Chrome windows and Claude, per the user. Desktops
2–7 (ids 7–12) are empty.

## Command

Probe snapshots, each read from `.live/status.json` (excerpts below are the
relevant fields, run on load and then three times via `hammerspoon://probe`;
all four runs agreed):

- `hs.spaces.allSpaces()`, `focusedSpace()`, `windowsForSpace(id)` per space,
  `spaceType()`, `missionControlSpaceNames()`
- `hs.window.allWindows()`, `orderedWindows()`
- `app:allWindows()` for Chrome, Claude, Code, Terminal
- `hs.window.get(id)` for every id `windowsForSpace(6)` returned
- `hs.window.filter.default`, a long-lived and a fresh `filter.new():setCurrentSpace(nil)`
- `app:focusedWindow()`, `app:mainWindow()` for Chrome and Claude

## Output

```
allSpaces: 8 spaces, one screen: 6, 7, 8, 9, 10, 11, 12, 234. focused 234
windowsForSpace(6):   13 ids  21035 23759 3736 23683 21036 37 21066 152 3738 3739 3740 21520 23685
windowsForSpace(7..12): 3 ids each, e.g. 7 → 21079 38 21080
windowsForSpace(234): 7 ids   21091 24036 20836 21092 21093 58 24051
missionControlSpaceNames(): nil

allWindows():      Terminal 20836, Code 24036, Hammerspoon Console 24051, 8× MenuBarAgent
orderedWindows():  Code 24036, Terminal 20836
app:allWindows():  Chrome 0, Claude 0, Code 1 (24036), Terminal 1 (20836)
hs.window.get(id) for all 13 space-6 ids: none resolved

filter.default:           Code 24036, Terminal 20836, Claude 23759, Chrome 3736  (+ MenuBarAgent on some runs)
filter anySpace (kept):   Code 24036, Terminal 20836, Chrome 3736, Claude 23759
filter anySpace (fresh):  Code 24036, Terminal 20836, Chrome 3736, Claude 23759

Chrome focusedWindow: id 3736 "Sign in successful | Claude Platform - Google Chrome", spaces [6], standard
Chrome mainWindow:    id 3736 (same)
Claude focusedWindow: id 23759 "Claude", spaces [6], standard
Claude mainWindow:    id 23759 (same)
```

## Conclusion

- **Finding 1 holds for enumeration, with one exception.** `allWindows()`,
  `orderedWindows()`, `app:allWindows()` and `hs.window.get(id)` see nothing
  on another space. **But `app:focusedWindow()` / `app:mainWindow()` return
  the app's frontmost window even when it is on another space**, as a fully
  readable handle (title, `isStandard`, `windowSpaces`). So: **one window
  per app**, the frontmost, is reachable off-space without ever having been
  seen. The second Chrome window on space 6 is not.
- **`hs.window.filter` uses exactly that trick.** `window_filter.lua`
  `App:getFocused()` falls back to `focusedWindow()`/`mainWindow()` and
  registers the result, with the comment "windows on a different space aren't
  picked up by :allWindows() at first refresh", and `App.new()` carries
  `TODO if a way is found to fetch *all* windows across spaces`. That is why
  the filter returned one Chrome window and Claude, and not the second Chrome.
- **Finding 3 holds:** `windowsForSpace()` returns ids for every space,
  including ones never visited this session. Ids include non-window surfaces:
  every empty desktop has 3, and space 6 has 13 for 3 real windows. The ids
  are only useful **cross-referenced with real handles**, not as a window list.
- **`missionControlSpaceNames()` returns nil on 27.0.1.** Desktop numbers are
  recoverable as positions in `allSpaces()` order (desktop "1" = id 6,
  desktop "8" = id 234), which matched the user's description.
- Open, for the next probe: does a handle **captured while visible** stay
  usable after leaving its space (finding 2)? Does `focus()` on an off-space
  handle switch space (finding 5)? Are ids reused (finding 4)?
