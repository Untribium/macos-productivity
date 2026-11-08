# Hammerspoon: window & input — design

Layers 1, 2 and 5 of `docs/keymap.md`: the fn nav layer, window cycling and
the glue around them. This file holds the goals, open questions and decision
log; the keyboard contract (layer ownership, namespace, keymap) is shared with
the other components and lives in `docs/keymap.md`. Install steps are in the
top-level `README.md`.

Formerly `SETUP.md` (split 2026-11-08; see the Decision log).

**If something isn't in here or in `docs/keymap.md`, it isn't decided.**

---

## Goal & constraints

**Goal:** keyboard-driven window management on macOS. Minimal mouse, no
trackpad gestures for window/space operations, muscle memory that survives
reboots and machine changes.

**Hard constraints:**

- [x] SIP: **cannot disable.** Corporate machine, no admin account.
- [x] **No admin rights at all.** Confirmed: privileged-daemon approval in Login
      Items & Extensions prompts for *username and password*, i.e. an admin
      account the user does not have. No MDM configuration profile is present
      (`profiles` empty, Privacy & Security → Profiles empty) — this is plain
      authorization, not policy. Effect is the same.
- [x] Displays: laptop + 2 externals. **Different external monitors at office
      and at home** — config must not hardcode display identities.
- [x] Keyboards: built-in + **Zeal60 rev3** (60%, QMK/VIA). No arrow keys on the
      60% ⇒ a nav layer is a functional requirement, not a nicety.
- [x] **Both keyboards must behave identically.** This is the constraint that
      drove the layer 0 decision. Verified at the event level for caps/fn on
      2026-08-30.
- [x] Must survive: macOS updates, and be reproducible from a repo.
- [x] Must not interfere with: terminal, IDE (vim user — Escape is load-bearing;
      IntelliJ — `ctrl+space` is load-bearing).

**Non-goals:**

- Tiling. Not wanted. Prior AeroSpace trial was unsatisfying coming from Linux
  tiling WMs — verdict was that a half-tiler is worse than no tiler.
- Automatic layout / auto-placement of new windows.
- Heavyweight launchers (Raycast, Alfred). Preference for scripting over
  large opinionated tools.
- Home-row mods. Ruled out — fights IDE bindings, and adaptation cost is not
  justified by the goal.

---

## Environment

| Field | Value |
|---|---|
| macOS version | 27.0.1 (this machine, as of 2026-10-25; was 26.6.2 when the goal, environment and keyboard sections were written) |
| Hardware | laptop + 2 externals (office set ≠ home set) |
| Keyboards | built-in; Zeal60 rev3 (VIA, stock caps lock) |
| Input sources | work machine: US ×2 + CH, cycled in one direction. This (personal) machine: ABC (Apple's US) + Swiss German. See Open questions "Input source switching" for why work has two US layouts |
| Admin rights | **none** |
| Shell | *(fill in)* |
| Dotfiles repo | `~/Projects/claude/macos-productivity` — this repo. Whether it merges into a larger dotfiles repo later is open; Install model assumes it stands alone. |

---

## Install model

**Install model: symlink, not copy.** `bootstrap.sh` symlinks the three entries
this repo owns into `~/.hammerspoon`, leaving Hammerspoon's own `Spoons/` alone.
After that, editing the repo edits the live config — no deploy step, no second
writable copy to drift. Backs up whatever was there first, and shows a diff
before doing it. `hammerspoon/Spoons/` is gitignored.

**Consequence for auto-reload:** FSEvents does not see writes that land on a
symlink's *target*, so a watcher on `hs.configdir` would silently stop firing
after bootstrap. `init.lua` resolves its own symlink and watches the repo
directory instead, falling back to `hs.configdir` when the config is a real
directory. `.live/status.json` → `watching` names the directory being watched;
that is the check (the load message itself is a brief `hs.alert`). Verified
2026-10-25 (`docs/verification/2026-10-25-auto-reload-through-symlink.md`).

### Driving the running config from a session

A session running natively on the Mac (Claude Code in the VS Code terminal)
runs as the user, so it can read `~/.hammerspoon` and run `defaults`. It can
also drive Hammerspoon through the fixed `hammerspoon://` endpoints in `modules/urlctl.lua`:

```sh
open -g hammerspoon://reload    # reload the config
open -g hammerspoon://status    # rewrite .live/status.json and .live/console.txt
cat .live/status.json           # watched dir, AX grant, one section per module
tail .live/log.txt              # diag.logger() lines, kept across reloads
grep -n ERROR .live/console.txt # errors and stack traces from callbacks
open -g hammerspoon://probe     # call run() on probes/active.lua, no reload
```

**Probes** that need to run on the Mac are Lua, not pasted commands:
write `hammerspoon/probes/active.lua` (gitignored, contract in
`probes/README.md`). Saving the file runs it. `://probe` runs later steps
without a reload, so captured state such as window handles survives a
space switch. Findings still go to `docs/verification/`; delete the file
when done.

`.live/` (gitignored, `modules/diag.lua`) is output only. Status and console are
rewritten on every load, so a newer `loaded` time confirms a reload happened.
Modules add their own state to the status file with `diag.provide()`; that
is how a window cache gets inspected without a console. Keypresses and
judging what is on screen still need a person. There is deliberately
**no `hs.ipc`** (Decision log), so `hs -c` does not work.

---

## Subtopic status

| Subtopic | Status | Depends on | Notes |
|---|---|---|---|
| Architecture / layer ownership | **done** (2026-08-30) | — | this document |
| Nav layer (caps → Escape + arrows) | **done** (2026-08-30) | architecture | verified on both keyboards |
| Config module structure | **done** (2026-08-30) | nav layer | loader / keymap / fnlayer; the code |
| Input source switching | **done** (2026-08-30) | nav layer | `caps+space`; three layouts, one direction |
| Repo & Cowork workflow | **done** (2026-09-01) | config module structure | Install model. `bootstrap.sh` applied 2026-10-25; `~/.hammerspoon` now links into the repo |
| Window moving & resizing (halves) | **next** | architecture | primary window use case. **First question is which modifier** — see Open questions |
| Displays & multi-monitor | ready | architecture | must handle office/home monitor swap |
| Space management | **blocked on verification** | `hs.spaces` test | may be dropped entirely. 2026-10-25 on 27.0.1: `allSpaces`/`windowsForSpace`/`focusedSpace`/watcher work; **`moveWindowToSpace()` returns true but does not move the window**; `missionControlSpaceNames()` returns nil; **`gotoSpace()` dead** (Mission Control AX tree empty on 27) |
| Window switching (focus) | **PoC working** (2026-10-25) | architecture | not a switcher: `` cmd+` `` cycling the app's windows **across spaces**, MRU. Findings re-verified; see Open questions "Window cycling across spaces" |
| Launcher & app switching | ready | architecture | Spotlight + direct-launch binds |
| Zeal60 firmware & physical layout | ready | nav layer | modifier row parity, Esc/backtick position, QMK fn audit |
| Browser | **needs own chat** | nav layer | choice of browser, extensions, scrolling, keyboard nav |
| Per-app rules & exceptions | blocked | all above | terminal, IDE exclusions |
| Packaging into dotfiles repo | **partly done** (2026-09-01) | all above | repo + `bootstrap.sh` exist; README must carry the System Settings steps, which are *not* file-based |

---

## Open questions

**Repo / workflow (new, 2026-09-01)**

- ~~`bootstrap.sh` has not been run.~~ **Done 2026-10-25.** The drift was
  comment-only in `keymap.lua`/`fnlayer.lua`, plus a live-only `winswitch.lua`
  loaded by the old `init.lua`, which is now archived in `docs/attic/` (see Decision log).
  Originals are in `~/.hammerspoon/.backup-20261025-150055/`. The stale
  `~/.hammerspoon/capsnav.lua` is not one of the linked entries, so bootstrap
  left it in place; it is unused and safe to delete (a copy is in the attic).
  The first run also showed that the script exited on the first drift it found
  (`diff` returns 1 under `pipefail`), so it could never have linked over
  drift. Fixed.
- ~~Does auto-reload survive the symlink?~~ **Yes, observed 2026-10-25.**
  Repo-side edits triggered a reload. `docs/verification/2026-10-25-auto-reload-through-symlink.md`.
- ~~Does `debug.getinfo(1,"S").source` give an absolute path here?~~ **Yes.**
  The watched directory is the repo path; the fallback did not fire. Same file.
- **Where do secrets / machine-specific values go?** Nothing needs them yet. If
  the window chat introduces per-location display config, decide then whether it
  is a gitignored local file or branching on `hs.screen` identity.

**Nav layer / layer 0**

- **Escape depends on a GUI setting.** Keycode 179 is only emitted while
  Keyboard → "Press 🌐 key to" is **Do Nothing**. If restored, Escape silently
  stops. Belongs in the README manual step alongside the Modifier Keys mapping.
- **Is 179 stable across macOS updates?** Undocumented. If it disappears, the
  timeout heuristic is the fallback — kept in the rejected table for that reason.
- **Secure input.** Event taps are disabled in password fields and at the lock
  screen; caps→Escape will not work there. Documented limitation, not a bug.
- **Does Hammerspoon need Input Monitoring** in addition to Accessibility for
  this tap? `docs/keymap.md` › Layer ownership currently claims Accessibility only — verify and correct if so.
- **Layer 0 is not reproducible from the repo, and is now three GUI settings.**
  Modifier Keys (per keyboard), "Press 🌐 key to → Do Nothing", and the Input
  Sources shortcut. All stored outside the dotfiles. Documented as manual steps
  in `README.md`, re-done on every new machine *and* every new keyboard.
- **Proposed, not decided — extra nav bindings.** `caps+u/d` (page up/down,
  replacing the fn+↑/↓ the 60% cannot reach), `caps+a/e` (line start/end, with
  selection falling out of pass-through for free). Both are already expressible
  in `keymap.lua` and sit commented out there awaiting a decision and a `docs/keymap.md` › Keymap row.
- `hs.eventtap` reliability: macOS can disable an event tap under load or after a
  timeout. Watchdog and wake-watcher are in the config from day one; watch
  whether they actually fire in practice.

**Window ops — which modifier? (undecided)**

- `alt` was listed as the window modifier in earlier drafts of `docs/keymap.md` › Keybinding namespace, but this was
  never resolved in a chat. It is now marked unallocated. Open both ways.
  - **For `caps`:** one modifier for "everything I added". It is also the only
    modifier verified comfortable and identical on both keyboards.
  - **For `alt`:** keeps window ops out of the nav namespace, and `hs.hotkey`
    binds it directly with no event tap involved — simpler, and unaffected if
    the fn mechanism ever regresses after a macOS update.
  - **Cost of `caps`:** collides with `caps+shift+hjkl` (selection) and
    `caps+alt+h/l` (word motion), which are currently free by-products of
    pass-through. Something has to move.
  - **Cost of `alt`:** depends on the Zeal60 bottom row sitting where the
    MacBook's does, which is a firmware task not yet done.
- **Either choice works mechanically.** `keymap.lua` specs take an `action`
  function as an alternative to `key`, so an fn-based window binding is a data
  entry, not a change to `fnlayer.lua`. This question is about namespace and
  ergonomics only.

**Window cycling across spaces (target set 2026-10-25)**

- **Target:** `` cmd+` `` cycles through **all windows of the frontmost app**,
  across spaces and displays. **Not a switcher**: no overlay, no list.
  Motivating case: Webex call and chat, or several Chrome windows, spread
  over spaces and monitors. Switching display B to another space strands the
  chat window, and cmd+` from the meeting window on display A must still
  reach it.
- **Decided scope:**
  - **MRU order.** Each press goes to the app's most recently used other
    window. The cache already holds handles; each entry gains a last-focused
    time, updated from focus events.
  - **Minimized windows ignored** for now. Adapt if it matters in practice.
  - **Full-screen spaces out of scope.** The user never uses full screen.
- **Mechanism, from the re-verified findings** (`docs/attic/README.md` table,
  `docs/verification/2026-10-25-*`):
  - Cache handles as windows are seen on visible spaces. They stay usable
    off-space, and `focus()` on one switches straight to its space with that
    window in front.
  - `app:focusedWindow()`/`mainWindow()` give each app's frontmost window on
    any space, with no visit needed.
  - The gap: an app's *other* windows on a space not seen since load. This is
    a macOS limit (AppKit space-filters `kAXWindows`). The only full fix is
    AltTab's private `_AXUIElementCreateWithRemoteToken` brute force: native
    code, an undocumented API, and it must stay off the main thread, which
    the fn tap shares. A last resort only.
  - Plain `hs.hotkey`, **no new event tap**.
- **Open, in rough order:**
  1. ~~What does native `` cmd+` `` do across spaces?~~ **Answered
     2026-10-25.** Two Chrome windows were on desktops 1 and 2. Native
     `` cmd+` `` does **nothing** with one window per space (no focus event
     fired), so it is current-space only. App Exposé (`cmd+tab` → ↓) **does**
     show both, because the Dock draws it with WindowServer access no
     client gets. Reusing it would mean opening App Exposé and reading the
     Dock's AX tree: visible, slow, and that tree already changed on 27
     (`missionControlSpaceNames()` → nil). Rejected as a basis.
     - Side finding: dragging a Chrome window produced a transient
       **non-standard** Chrome window (no title, gone seconds later) that
       still received a focus event. The cache must ignore `isStandard() ==
       false`, or Chrome will fill it with junk.
  2. **Which key, exactly.** The user presses "the key left of 1". Bind by
     keycode, which does not change with input layout. But that key's
     keycode depends on the keyboard: on ISO hardware (CH built-in) it is
     `§`, keycode **10**, and macOS swaps 10↔50 for ISO boards; on ANSI it
     is grave, keycode **50**. **On the Zeal60 the key left of 1 is Esc
     (keycode 53)**, so a position-based binding there is `cmd+Esc`, while
     the character `` ` `` is an fn-chord (see the Zeal60 note below). Probe:
     log the keycode on each keyboard, then pick per-keyboard keycodes, or
     one binding plus firmware parity.
     - **User plans Zeal60 firmware parity** (2026-10-25): Esc → `` ` `` and
       MacBook modifier order. Then the key left of 1 matches on both
       boards, and this mostly resolves. **Caps must stay stock Caps Lock in
       firmware** (Decision log 2026-08-30: there is no QMK keycode for Apple's Globe,
       and layer 0 is the per-device OS remap of what the device sends).
       Firmware "caps → fn" would break the nav layer on the Zeal60.
     - **Idea to evaluate (user, 2026-10-25): firmware caps → Esc, OS Esc → fn.**
       The Zeal60 would send Esc from the caps position, so on any machine
       without this setup, vim still gets Escape. On this machine, Esc from
       *that device only* would become fn, and the nav layer works as today.
       Sound in principle. Unknowns:
       (a) the Modifier Keys pane only takes modifiers as the **source**, so
       Esc → fn needs `hidutil property --matching '{"ProductID":…}' --set
       '{"UserKeyMapping":[…]}'` per device. Check that it needs no admin,
       and persist it with a LaunchAgent in `~/Library/LaunchAgents`;
       (b) whether `hidutil` can target Apple's fn usage
       (`0xFF00000003`);
       (c) whether a hidutil-made fn still produces the lone-tap keycode 179
       that Escape depends on (`docs/keymap.md` › Keybinding namespace), and still survives "Press 🌐 key to: Do
       Nothing".
       If (c) fails, Escape-on-tap would need a timing heuristic, which Decision log
       rules out. Probe before flashing anything.
  3. ~~Catching off-space windows from AX notifications.~~ **Confirmed
     2026-10-25** (`docs/verification/2026-10-25-ax-notifications-and-id-reuse.md`).
     A per-app `hs.axuielement.observer` on the application element received
     `AXTitleChanged` for a Chrome window on another space and resolved it to
     a usable handle, which `focus()` then switched to. The probe never
     enumerated that window. So the cache fills from any window that changes,
     and the gap shrinks to windows that stay completely static.
     New windows open on the **current** space, even when an off-space
     window opened them, and are reported at once. Destroy notifications
     cannot be resolved to a window, and **the window filter misses
     off-space closes entirely**. Liveness test: **`windowSpaces(id)`
     non-empty**. It is cheap (WindowServer, no AX round-trip), so prune
     every entry on each press, and admit an entry only once it has a space
     (new windows briefly report `{}`).
  4. **Webex.** Are the call and chat windows the same process? If not,
     "same app" will not link them. Probe with a free account on this
     machine, after Chrome works.
  5. ~~Window id reuse after app restart~~ **Not reused** in one trial
     (TextEdit 26141, then 26150 after a restart; ids grow monotonically all
     session). Prune closed windows, but no defence against reuse is needed.
  6. **Later: detecting unknown windows.** Learn each space's non-window ids
     on visit; afterwards, a new unclassified id means a window opened there
     unseen. Ids carry no owner (`hs.window.list` is on-screen only), so the
     signal is per space, not per app. If built, surface it as **a
     notification with a "refresh" button** that steps through the affected
     spaces and returns. **Never automatic.** Noise stability **checked
     2026-10-25**: over 23 min, unvisited spaces kept identical id sets. The
     one change was Chrome's non-standard companion window 3738 following
     its real window 3736 from space 6 to 7. So **classify ids system-wide,
     not per space**, or a moved window's companion looks like an unknown
     window. Still open: do synthetic ⌃N presses switch reliably?
- **PoC timing (2026-10-25):** a press costs 9–29 ms inside Hammerspoon,
  same-space or cross-space (snapshot ≤14 ms, `focus()` ≤21 ms). The
  extra time on cross-space presses is macOS's space switch (a crossfade
  with Reduce Motion), not the module. To confirm: compare with ⌃N.
- ~~Chrome favicons in the overlay~~ **Dropped 2026-10-25, keep it simple.**
  Found: the active tab's URL **can** be read from the window's address bar via
  AX, including off-space, in 3–11 ms (Chrome omits the scheme and trims the
  path, so match by domain). But the icons live in Chrome's `Favicons` DB,
  under `~/Library/Application Support/Google/Chrome`, and macOS 27 blocks
  reading it (`Operation not permitted`, the "data from other apps"
  protection). Alternatives were rejected: granting Hammerspoon that
  permission (it covers every app's data); fetching `/favicon.ico` from each
  site (network calls outside the browser); AppleScript/JS into Chrome (two
  more permissions). If ever wanted, showing the domain as text needs only
  the AX read.
- **Cache refresh (2026-10-25, in progress):** a notification with a
  "Refresh" button works: `hs.notify` with `hasActionButton`; the action click
  arrives as `activationType` 2 and "Later" sends nothing. It needs Hammerspoon
  notifications **on**, style **Persistent** (enabled by the user 2026-10-25).
  The `presented()` flag stays false even when shown, so it is unreliable.
  Id-based unknown detection is meaningless right after a reload: every
  unvisited space's own system ids look unknown. Use **"desktops not visited
  since load"** as the signal; per-id detection only after a visit.
  **`hs.spaces.gotoSpace()` is dead on 27.0.1, confirmed.** It opens Mission
  Control and presses a desktop in the Dock's AX tree (group `mc` →
  `mc.display` → `mc.spaces`). On 27 the `mc` group appears ~100 ms after
  opening but stays **empty** (0 children, empty frame) for 3 s of polling.
  It is not timing and not an ID mismatch; the strip is no longer exposed.
  `missionControlSpaceNames()`, `addSpaceToScreen()` and `removeSpace()` use
  the same tree. Routes left: `focus()` on a cached window (any space with
  a known window), and keyboard shortcuts (empty or unseen spaces). Switching must go through keyboard
  shortcuts: a sweep uses **"Move left/right a space"**, which works with any
  number of desktops (the user sometimes has more than 10); "Switch to
  Desktop N" exists only for 1–16. Both could sit on unreachable hyper
  chords, like `caps+space` (Decision log), so the user's own keys stay free.
  **Synthetic shortcuts work** (`hs.eventtap.keyStroke`, 2026-10-25, Reduce
  Motion on). From the keystroke until `allWindows()` shows a window on the
  new space: **~1.7 s** for a relative step (⌥⇧K/J), **~1.0 s** for a direct
  ⌃N. `focusedSpace()` can change earlier. **`hs.spaces.watcher` missed 2 of
  4 switches**, so a refresh must poll `allWindows()` for windows on the new
  space, with a timeout for empty desktops, not wait on the watcher.
  Sweep cost: ~1.7 s per desktop stepping, ~1 s per direct jump.
  **Multi-monitor, to check with a second screen:** with "Displays have
  separate Spaces", every display's current space is visible already, so only
  hidden spaces need a visit; "Move left/right" acts on the focused display,
  so a sweep runs per display; does "Switch to Desktop N" number per display
  or across all of them?
  **Which shortcuts to send:** a Keyboard Shortcuts row holds exactly one
  chord, so there is no second system binding for Hammerspoon's own use. At
  runtime, **read** rows 118–133 (Desktop N) and 79/81 (move left/right) and
  send whatever is enabled, by keycode. If a row is missing, fall back
  (relative steps) and say so. **Do not write the settings at runtime.**
  Creating missing rows on hyper chords belongs to the layer-0 bootstrap
  to-do, mindful of the Open questions traps (disabled rows still claim chords; no two
  rows on one chord). Verify every switch by polling, since an enabled
  binding can still fail (⌃8 does), and fall back on a timeout.
- **Later (user, 2026-10-25): the reload alert is ugly.** `init.lua` uses a
  plain `hs.alert`. Restyle it, e.g. a small transient `hs.canvas` toast reusing
  the wincycle overlay's glass palette (`modules/wincycle.lua` `palette()`).
- **To do (user, 2026-11-07): a per-machine config mechanism.** Everything in
  `keymap.lua` and `init.lua` currently loads on every machine; only
  `config/local.lua` (gitignored, one value) is per machine. The Citrix
  modules only make sense on the work laptop, and the wincycle keycode
  differs per keyboard (10 on the work ISO board, 50 on this ANSI
  built-in). Stopgap: `keycodes = { 50, 10 }` on every machine. On ISO, 50
  is a different physical key, so this may cause a stray binding there;
  watch for it. Needed: a way for each machine to choose its modules and
  override values. Rough shape (user): enable modules per machine and, for
  each, define the keys it uses. Alternative for keys like this one: a
  one-time "press the key left of 1" capture that stores the keycode
  locally (in `config/local.lua` or similar), so nobody has to know
  keycodes.
- **To do: script layer 0 instead of README manual steps.** `bootstrap.sh`
  only symlinks. Keyboard Shortcuts rows (input source, desktop switching)
  can be written with `defaults write com.apple.symbolichotkeys` +
  `activateSettings -u`, with no admin. Caps → fn is per device in the global
  domain (`com.apple.keyboard.modifiermapping.<vendor>-<product>-0`); check
  whether it applies without logging out. "Press 🌐 key to" is
  `com.apple.HIToolbox AppleFnUsageType`, to verify. Matters more as the
  hyper channel grows.
- Side note: ⌃8 ("Switch to Desktop 8") did nothing when tried. Not
  investigated; something may be taking ⌃8 first.

**Input source switching — resolved, with a trap worth remembering**

- Resolved: no layout list lives in the config. The tap re-emits hyper+space and
  the OS shortcut cycles whatever is enabled, in the Input menu's own order.
  Adding or removing a layout needs no config change.
- **Trap:** Keyboard Shortcuts rows 60 ("Select the previous input source") and
  61 ("Select next source in Input menu") must not hold the same chord. A
  *disabled* row still claims its shortcut and swallows the keystroke —
  unchecking is not releasing, and the pane gives no indication. Symptom: the
  chord works on one row and silently does nothing on the other.
  - Diagnose: `defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys`,
    compare the `parameters` triples for 60 and 61.
  - Clear a row properly with parameters `(65535, 65535, 0)`, then
    `activateSettings -u` to reload without logging out.
- More generally: when a Keyboard Shortcuts binding misbehaves, read the plist
  before believing the pane.
- **To investigate some day: layout switching is still a pain.** Two ideas:
  - **Automatic layout per app.** Is it feasible? Hammerspoon can see app
    activation, and `hs.keycodes` can read and set the current source, but
    `setLayout` breaks on IMEs (Decision log). Possibly too hard; noted, not planned.
  - **Why work has two US layouts.** The hardware there is CH (ISO), and
    with macOS's own US layout `` ` `` and `~` were not where they should be.
    That is likely the ISO keycode swap (10 ↔ 50), which is widely reported
    and leaks into browsers. Check whether the default US layout now behaves
    on the work machine, so it can drop the second US layout. This machine
    uses ABC + Swiss German.

**Zeal60**

- **Modifier row parity.** Bottom row likely ships in Windows order
  (`ctrl/win/alt`) vs the MacBook's `ctrl/alt/cmd`. Do in **firmware, not OS** —
  Modifier Keys is one-modifier-to-one-modifier only, and every row added there
  is another per-device GUI setting outside the repo. **Caps must keep sending
  stock Caps Lock**: the layer 0 remap is keyed to what the device sends and is
  verified working. Reshape everything else, leave caps alone.
  - This feeds the window-modifier question: until firmware parity is done,
    `alt` may not sit in the same place on both keyboards.
- **QMK fn layer** — audit in VIA. It may restore keys the built-in has in
  hardware (F-row, media, delete) but must not provide navigation, or the two
  keyboards diverge. Confirm its fn is a plain `MO()` and never sends a real fn
  keycode, which would collide with the nav layer.
- **Esc sits where backtick usually is.** Backtick is therefore likely an
  fn-chord, making `` cmd+` `` (cycle windows in app) a two-hand reach on the 60%
  and a single reach on the built-in — an ergonomic divergence in an existing
  binding. Feeds the window-switching subtopic: prefer a binding of our own that
  is comfortable on both keyboards over inheriting `` cmd+` ``. Note `` cmd+` ``
  is in the "do not take" row, so shadowing it needs a decision-log entry.
  **Update 2026-10-25:** shadowing it is now decided (Decision log), and the binding is
  by physical key; see "Window cycling across spaces" item 2.

**Browser**

- **Browser is a subtopic of its own** — browser choice, extensions, scrolling
  behaviour, in-page keyboard navigation. Mostly application config rather than
  a layer in `docs/keymap.md` › Layer ownership, so it may not belong in this document at all beyond the points
  where it collides with the stack. Two things it must answer: (a) does
  `caps+j/k` scroll in the browser, or does the browser want its own scroll
  binding — this is a **per-app rules** question and a genuine layer 1 concern;
  (b) does any extension take bindings that collide with the namespace in `docs/keymap.md`
  reservations. Vim-style extensions in particular claim `hjkl` and `Escape`,
  both of which the nav layer now owns globally.

**Rest of stack**

- **Does `hs.spaces` work reliably on 26.6.2?** It is built on undocumented
  CoreGraphics calls and is the most likely thing to break on a macOS update.
  Needs an empirical test before any space binding is committed. If it fails,
  layer 3 has no owner and space management is dropped from scope.
- How is window state restored after a reboot / display disconnect?

---

## Decision log

Append-only. Each entry: what was decided, why, and what it rules out.

Entries before 2026-11-08 cite sections of the old `SETUP.md` by number, and
are left as written: §0 → Install model, §1 → Goal & constraints, §2 →
Environment, §3–§5 → `docs/keymap.md`, §6 → Subtopic status, §7 → Open
questions, §8 → this log, §9 → Config file inventory, §10 (embedded code) →
dropped, read the files.

| Date | Decision | Rationale | Rules out |
|---|---|---|---|
| 2026-08-30 | No tiling window manager | Tiling is a non-goal; prior AeroSpace trial unsatisfying vs. Linux WMs. Actual need is halves + movement between displays/spaces. | AeroSpace, yabai, and their workspace models |
| 2026-08-30 | No SIP changes | Corporate machine, no admin. | yabai space ops, anything needing partial SIP disable |
| 2026-08-30 | **Karabiner-Elements ruled out** | Input remapping is done by `Karabiner-Core-Service` running as **root** to seize devices; the VirtualHIDDevice daemon is root too. Approval requires an admin account (prompt asks for username *and* password). Installing the pkg with elevated rights does not help — the SMAppService approval is a separate, later gate. | Hyper key, home-row mods, HID-level per-device rules, dual-role keys at the driver level |
| 2026-08-30 | Layer 0 = macOS Modifier Keys, per-keyboard | Only no-privilege remapping mechanism available. Crucially it is per-device, so built-in and Zeal60 can be made to behave identically without firmware changes. | Any layer-0 rule more complex than one-modifier-to-one-modifier |
| 2026-08-30 | Caps Lock → fn (Globe), → Control (fallback) | fn leaves `ctrl` free, avoiding emacs/readline clashes. Control is the known-good fallback if fn handling is flaky. | Caps as a true hyper key |
| 2026-08-30 | Zeal60 firmware stays stock *for caps* | Apple's Globe is a vendor-specific HID usage with no mainline QMK keycode and no VIA support. The OS remap is per-device and verified working; changing what caps sends would break it. | QMK/VIA nav layer, firmware-side caps handling |
| 2026-08-30 | Hammerspoon owns layers 1, 2, 5 | Needs Accessibility only — no daemon, no admin. Matches the preference for scripting over large tools. One config tree in the repo. | Rectangle, Loop, skhd, Raycast, Alfred |
| 2026-08-30 | Spotlight for launching | Adequate; avoids a heavyweight tool owning layer 4. | Raycast, Alfred |
| 2026-08-30 | Tap→Escape via synthetic keycode 179 | macOS emits a lone keyDown 179 on an unchorded Globe tap. System-computed, so no timing heuristic. | Timeout/dirty-flag tap detection, and its fast-chord false-positive class |
| 2026-08-30 | Nav cluster stays on `hjkl` | Session event tap intercepts Globe+H and Globe+E before the system and suppresses both. Verified on both keyboards. | Relocating to `jkl;`; any Keyboard Shortcuts workaround for Globe+H |
| 2026-08-30 | Zeal60 firmware may reshape to **match** the built-in, never to exceed it | Same principle that ruled out a QMK nav layer, applied in the convergent direction: F-row and modifier parity make the keyboards identical, a nav layer would make them diverge. | Zeal60-only capabilities; OS-side multi-modifier remapping |
| 2026-08-30 | `caps+space` cycles input source; it re-emits hyper+space, and the OS "next source" shortcut is moved onto that chord | Tap-to-switch was lost to the "Do Nothing" setting Escape depends on, and language switching is the highest-frequency non-nav action, so it earns the prime slot. The recorder will not accept fn, so a tap is required regardless; addressing the native shortcut via an unreachable chord keeps the layout list in the system rather than in the config, and frees `ctrl+space` for IntelliJ. Three layouts, one direction is sufficient. | Hardcoding layouts in the config; `hs.keycodes.setLayout` (breaks on IMEs); `ctrl+space`; double-tap caps; binding fn natively in Keyboard Shortcuts |
| 2026-08-30 | Config split: `init.lua` loader, `config/keymap.lua` data, `modules/fnlayer.lua` mechanism. **Exactly one tap owns fn.** | Bindings change often, the tap does not, so adding a binding should be a data edit. The single-tap invariant is forced by the mechanism: two taps on fn give nondeterministic ordering and double consumption. Specs accept an `action` function so non-keystroke bindings need no mechanism change. | Per-feature event taps; any module creating its own fn tap |
| 2026-09-01 | Repo at `~/Projects/claude/macos-productivity`; config under `hammerspoon/`, prose at the root, probe output in `docs/verification/` | Layer 0 is GUI settings and every macOS probe has to be run by hand, so the repo has to carry prose and evidence, not just Lua. Flat and boring beats clever — one config dir, one docs dir. | A bare dotfiles-style tree with no place for verification output |
| 2026-09-01 | **Install by symlink**, via a dry-run-by-default `bootstrap.sh` that backs up first | A copy/deploy step means two writable copies and silent drift between the repo and what is actually running — the exact failure this document exists to prevent. Symlinking makes the repo the live config. Dry-run default and a diff before overwriting keep a verified-working setup from being clobbered by a stale repo. | `rsync`-style deploy; connecting `~/.hammerspoon` as a second editable folder; editing the live config directly |
| 2026-09-01 | `init.lua` watches its **resolved** directory, not `hs.configdir` | FSEvents does not report writes that land on a symlink's target, so the original watcher would have stopped auto-reloading the moment bootstrap ran — and failed silently, which is worse than not having it. | Keeping the naive `hs.pathwatcher.new(hs.configdir)` under a symlink install |
| 2026-09-01 | `SETUP.md` lives in the repo; project knowledge holds a mirror, repo wins | The doc and the config it describes change in the same edit and belong in the same commit. The mirror keeps chats that are not connected to the folder working, at the cost of one sync step per session. | Project knowledge as the authoritative copy; dropping the project doc and losing unconnected chats |
| 2026-09-01 | macOS-side facts are gathered as **probes**: user runs the command, output is filed in `docs/verification/` | A Cowork session's shell is a Linux VM with only this folder mounted — `defaults`, `hs`, and System Settings are all unreachable from it. Writing probes down as artefacts stops each session re-asking the same question. | Any workflow that assumes a session can inspect the running macOS |
| 2026-10-25 | Pre-repo `winswitch.lua` (alt+tab cross-space MRU switcher) **retired** to `docs/attic/`, not brought into the config | It was never designed against this document (no §4/§5 rows, a second event tap) and is not the switching behaviour wanted. Its findings about off-space window handles are recorded in `docs/attic/README.md` for the window-switching subtopic. | Reviving `winswitch.lua` as the starting design; `alt+tab`/`` alt+` `` as implicitly taken |
| 2026-10-25 | Hammerspoon is driven from the shell through **fixed `hammerspoon://` URL endpoints** (`reload`, `status`), never `hs.ipc` | `hs.ipc` lets any process running as the user run arbitrary Lua, and so borrow Hammerspoon's Accessibility grant for keylogging and synthetic input, which macOS would otherwise block per app. Parameterless endpoints cap the worst case at a reload or a rewritten status file, and still cover reloading and status checks from a native session. | `hs.ipc` / `hs -c`, except temporarily for one session and removed afterwards; endpoints that take params or evaluate input |
| 2026-10-25 | Running-config diagnostics go to files in a gitignored `<repo>/.live/` (log, console dump, status with per-module `diag.provide()` sections); the config watcher starts before any module | A shell session cannot see the Hammerspoon console, and switcher work needs the window cache visible without one. Files are output only, so this adds observability without adding input surface. The watcher order means a module that fails to load can still be fixed by saving a file. | Debugging by asking the user to copy console text; module state exposed by evaluating Lua; synthetic keypresses from the shell (would need Accessibility for the terminal) |
| 2026-10-25 | **Correction to the `hs.ipc` row above:** the endpoints are a convenience and a narrow interface, **not a security boundary**. Added `hammerspoon://probe` and a gitignored `hammerspoon/probes/active.lua` probe runner | That row's rationale was overstated. The config itself is the way in: any process running as the user can write `.lua` into the watched directory, or edit it and relaunch Hammerspoon, and so already borrow the Accessibility grant. That is true of every Hammerspoon install and is not fixable without admin (a root-owned config); disabling the watcher only delays it. So running probe code from a file in the repo adds no exposure beyond the config. Real mitigations: grant Hammerspoon nothing beyond Accessibility; config changes are visible in git; review edits to `hammerspoon/`, including Claude's. | Disabling auto-reload as a security measure; `chflags uchg` (the user can clear it); treating `hs.ipc` as the main risk. `hs.ipc` stays out, because the endpoints are enough, not for security |
| 2026-10-25 | Window switching target: **`` cmd+` `` cycles the frontmost app's windows across spaces and displays, MRU order**; minimized windows ignored; full screen out of scope. **No switcher or overlay**, at least initially | The real need is reaching the *other* window of the same app (Webex call ↔ chat, several Chrome windows) after spaces have moved under it. Per-app MRU covers that with a plain hotkey: no overlay, no modifier-release tap, no new event tap. The cache of captured handles plus `focusedWindow`/`mainWindow` was re-verified as sufficient, except for windows never seen since load. | `winswitch.lua`-style system-wide alt+tab switcher with overlay (for now); including minimized windows; full-screen support |
| 2026-10-25 | **Exception to the `cmd` "do not take" row:** the key left of `1` (with `cmd`, and `cmd+shift` for reverse) is taken for window cycling, bound by **keycode**, not character | It replaces macOS's own window-cycling shortcut on the same key, so no app binding is lost. Keycodes are layout-independent, so switching CH/US input does not move the binding. Characters are not: `` ` `` lives on different physical keys per layout and per ISO/ANSI hardware. | Binding by character (`hs.hotkey` with `` "`" ``); a new chord elsewhere just for the 60% before the keycode probe has run |
| 2026-10-25 | **Partial revision of "no switcher or overlay":** window cycling switches **on cmd release** (cmd+tab model), and shows an overlay from the second press or after 0.3 s held. A quick tap still toggles with no overlay. Behind `overlay` in `keymap.lua` | With 5–7 windows of one app, stepping by focusing each window switched spaces on every press, which was slow and disorienting. Selecting without switching and switching once on release fixes that. A quick tap is unaffected. The overlay is `hs.canvas` styled after Liquid Glass but cannot blur (no Screen Recording). Still per-app only, not a system-wide switcher. | Focusing on every press; switching on the first press, then overlaying (two space switches); window thumbnails (need Screen Recording); a system-wide switcher (still out) |
| 2026-11-08 | **`SETUP.md` split by component.** Layer ownership, namespace and keymap → `docs/keymap.md`, shared by all components; the rest → `hammerspoon/DESIGN.md`. Standing rules for sessions → `CLAUDE.md`. §0's Cowork workflow and the project-knowledge mirror procedure dropped, as was §10 (the config embedded verbatim) | A second component (`overlay/`, native Swift) binds into the same keyboard namespace, so the keyboard contract can no longer live inside one component's doc. Sessions now mostly run natively and read the files directly, and Claude Desktop projects can sync the repo from GitHub, so a hand-synced mirror and a 900-line code copy only add drift. | A single repo-wide `SETUP.md`; per-component copies of the keymap; keeping the mirror sync step |

---

## Config file inventory

Repo paths are relative to `~/Projects/claude/macos-productivity`. Live paths are
what Hammerspoon reads; the arrow is the symlink `bootstrap.sh` creates.

| File | Repo path | Live path | Owns layer(s) |
|---|---|---|---|
| `init.lua` | `hammerspoon/init.lua` | → `~/.hammerspoon/init.lua` | loader only — no bindings, no logic |
| `keymap.lua` | `hammerspoon/config/keymap.lua` | → `~/.hammerspoon/config/` | bindings as data; machine-readable twin of `docs/keymap.md` › Keymap |
| `fnlayer.lua` | `hammerspoon/modules/fnlayer.lua` | → `~/.hammerspoon/modules/` | 1 — **sole owner of the fn tap** |
| `wincycle.lua` | `hammerspoon/modules/wincycle.lua` | → `~/.hammerspoon/modules/` | 2 — `` cmd+` `` across spaces; window cache, per-app AX observers, no event tap |
| `citrixfocus.lua` | `hammerspoon/modules/citrixfocus.lua` | → `~/.hammerspoon/modules/` | none — Citrix Viewer workaround: a mouse move on activation clears focus from the hidden toolbar notch (Workspace 2609) |
| `citrixsignin.lua` | `hammerspoon/modules/citrixsignin.lua` | → `~/.hammerspoon/modules/` | none — types the email and presses Return when the Citrix sign-in window gains focus, once per window. The window is focused *before* its title is set, so it also listens for title changes |
| `local.lua` | `hammerspoon/config/local.lua` | → `~/.hammerspoon/config/` | none — machine-local values (`citrixEmail`); **gitignored**, so a fresh clone must create it |
| `bootstrap.sh` | `bootstrap.sh` | — | creates the three symlinks above; dry run by default |
| `urlctl.lua` | `hammerspoon/modules/urlctl.lua` | → `~/.hammerspoon/modules/` | none — `hammerspoon://reload` and `://status` endpoints; writes `.live/status.json` |
| `probes/` | `hammerspoon/probes/` | — *(read from the repo path by `init.lua`; not linked)* | none — `README.md` tracked; `active.lua` gitignored, run on load by `init.lua` |
| `diag.lua` | `hammerspoon/modules/diag.lua` | → `~/.hammerspoon/modules/` | none — `logger()` and `provide()` for modules; owns the gitignored `.live/` |
| `docs/attic/*.lua` | `docs/attic/` | — *(not linked, not loaded)* | none — retired `winswitch.lua`, `capsnav.lua`, kept for learnings |
| *(not in repo)* | — | `~/.hammerspoon/Spoons/` | Hammerspoon's own; gitignored, left alone by bootstrap |
| *(GUI setting — not a file)* | README manual step 1 | System Settings → Keyboard → Modifier Keys, **per keyboard** | 0 |
| *(GUI setting — not a file)* | README manual step 2 | Keyboard → "Press 🌐 key to" → **Do Nothing** | 0 — Escape depends on this |
| *(GUI setting — not a file)* | README manual step 3 | Keyboard Shortcuts → Input Sources → "Select next source in Input menu" = `⌃⌥⇧⌘Space`, **and the "previous source" row cleared, not merely unchecked** | 0 — `caps+space` depends on this |
| *(firmware — not a file in this repo)* | — | Zeal60 VIA keymap | physical layout parity only |
| `DefaultKeyBinding.dict` | *(not written)* | `~/Library/KeyBindings/` | *(only if the Control fallback is adopted)* |

**Drift:** `docs/keymap.md` › Keymap and `keymap.lua` state the same bindings — `docs/keymap.md` › Keymap with rationale, the
Lua without. Every binding decision is a two-file edit, in one commit.
