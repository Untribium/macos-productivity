# AX notifications from off-space windows; window id reuse (macOS 27.0.1)

- **Date:** 2026-10-25
- **Question:** SETUP.md §7 "Window cycling across spaces", open items 3 and
  5. Do AX notifications hand over windows on other spaces? Are window ids
  reused after an app restarts (attic finding 4)?
- **Machine:** macOS 27.0.1, Hammerspoon 1.1.1, one screen

## Probe 3: AX notifications

`hammerspoon/probes/active.lua`: one `hs.axuielement.observer` on Chrome's
application element, watching `AXTitleChanged`, `AXWindowCreated`,
`AXUIElementDestroyed`, `AXFocusedWindowChanged`, `AXMainWindowChanged`,
`AXWindowMoved`, `AXWindowResized`, `AXValueChanged`. The probe **never
enumerates windows**, so it can only learn one through a notification. Each
notification is resolved to its window (`AXWindow` attribute, then
`asHSWindow()`) and logged with that window's space and the current space.

Setup: Chrome window 3736 (WhatsApp tab) on desktop 2 (space 7). The user
stayed on desktop 8 (space 234). First trigger: a WhatsApp message changed
the tab's unread count. Second: the user added a tab, then returned to 234:

```
data:text/html,<script>let n=0;setInterval(()=>document.title='tick '+(++n),3000)</script>
```

### Output

```
16:34:15 observing Chrome pid 1111 for 8 notifications; on space 234
16:45:15 note AXTitleChanged → win 3736 std=true spaces={ 7 } here=234 OFF-SPACE (first sighting)
16:45:27 note AXWindowCreated → win 3738 std=false spaces={ 7 } here=7 on-space (first sighting)
16:45:37 note AXTitleChanged → win 26124 std=false spaces={} here=7 OFF-SPACE (first sighting)
16:45:55 note AXTitleChanged → win 3736 std=true spaces={ 7 } here=234 OFF-SPACE
16:45:55 note AXValueChanged → win 3736 std=true spaces={ 7 } here=234 OFF-SPACE
   … every 3s …
16:46:22 focuslearned: focus(3736) from space 234 ok=true
16:46:24 focuslearned: now space=7 focused=3736
```

### Conclusion

- **Confirmed: AX notifications hand over off-space windows.** Window 3736
  was first learned **while the user was on 234**, from the WhatsApp title
  change alone. The probe had never enumerated it, and it was not Chrome's
  main window. This matches AltTab's `src/windowserver/README.md`.
- **The handle is usable.** `focus()` on the notification-learned handle
  switched to space 7 with 3736 focused.
- `AXTitleChanged` and `AXValueChanged` fire on each title change.
  Non-standard Chrome windows (3738, a companion window; 26124, transient)
  also notify, and the cache must drop them with `isStandard()`.
- **Design impact:** per-app observers fill the cache with any window that
  changes, so the "never seen since load" gap only covers windows that
  stay completely static. Keep observers on the apps that matter (at least
  the frontmost), not on every process.

## Finding 4: window id reuse

TextEdit opened on `.../scratchpad/idreuse.txt` (`open -a TextEdit`), ids read
through the probe's `teids` step, `pkill -x TextEdit`, repeated:

```
16:56:14 teids: TextEdit pid=62675 windows={ 26141 }
16:56:19 teids: TextEdit pid=62704 windows={ 26150 }
16:56:22 teids: TextEdit pid=none windows={}
```

### Conclusion

- **Not reused** across an app restart: 26141, then 26150. Ids observed all
  session grow monotonically (oldest windows ~3700, newest ~26000), which is
  consistent with one counter for the whole login session.
  **Attic finding 4 does not hold** on this evidence. One short trial only;
  revisit if the cache ever shows an id pointing at the wrong window.
- Pruning is still needed, but to drop **closed** windows, whose handles go
  dead. It is not needed to defend against id reuse.

## Addendum: a window opened by an off-space app

A probe (Chrome only, listening only) watched `AXWindowCreated` /
`AXUIElementDestroyed` on the app element and `windowCreated` /
`windowDestroyed` on a window filter. On desktop 2, the user clicked a
button in a tab of Chrome window 3736 that ran
`setTimeout(()=>window.open('about:blank','_blank','popup,width=500,height=400'),4000)`
(the delay stays inside Chrome's ~5s user-activation window), then pressed
⌃8 at once.

```
17:00:22 wf created → win 26209 std=true title="about:blank - Google Chrome" spaces={ 234 } here=234
17:00:22 ax AXWindowCreated → win 26209 std=true title="about:blank - Google Chrome" spaces={ 234 } here=234
17:00:31 ax AXUIElementDestroyed → (not a window)      ×7
```

- **The new window opened on the user's current space (234)**, not the
  opener's (7). Both the filter and the AX observer reported it at once.
  New windows are therefore visible, and cached the normal way.
- **`AXUIElementDestroyed` cannot be resolved to a window**: by the time it
  arrives, the element is dead. That includes ordinary tab closes. **Prune
  lazily** instead: when cmd+\` picks a cached handle that is dead, drop it
  and take the next.
- Untested: an app **assigned to a desktop** (Dock → Options → Assign To)
  opens windows on that desktop, which would be a genuinely off-space
  creation. Notifications are not space-filtered, so it is probably still
  caught. Check with Webex if it gets assigned.
