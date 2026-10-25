# macOS Window & Input Setup — Source of Truth

> **Read this box first — there are two copies of this file.**
>
> The authoritative copy lives in the **repo**, at
> `~/Projects/claude/macos-productivity/SETUP.md`. A **mirror** is kept in Claude
> project knowledge so that chats without the folder connected (phone, web) can
> still work. The mirror is a snapshot and is stale by definition.
>
> - **If this session has the folder connected:** read the repo copy and ignore
>   the project-knowledge one. Check they agree — the mirror carries a
>   `Mirror synced:` line naming the commit it was taken from; if that is not
>   `git log -1`, the mirror is behind and the repo is right. Never merge the
>   mirror back.
> - **If this session does NOT have the folder connected:** you are reading the
>   mirror. Say so up front. You may reason, design and propose, but you cannot
>   see the live config, so treat §10 as possibly out of date and do not claim
>   anything is verified. Any decision reached here has to be re-applied in a
>   connected session before it is real.
>
> Any chat that changes a binding, a tool choice, or a layer boundary must
> produce a diff to this file. If something isn't in here, it isn't decided.

**Status:** architecture decided; nav layer built and verified; repo live via symlinks; window-cycling target set, building next
**Last updated:** 2026-10-25

---

## 0. Repo, workflow, and how a Cowork session works

**Repo:** `~/Projects/claude/macos-productivity` — connected to Cowork sessions
as a folder, and the only part of this machine a session can see.

```
macos-productivity/
├── SETUP.md              # this file — source of truth, git-tracked
├── README.md             # install + the manual GUI steps, for a new machine
├── bootstrap.sh          # dry-run by default; links hammerspoon/ into ~/.hammerspoon
├── hammerspoon/          # symlinked into ~/.hammerspoon (init.lua, config/, modules/)
│   ├── init.lua          #   loader only
│   ├── config/keymap.lua #   bindings as data — the file you edit
│   └── modules/fnlayer.lua #  the fn tap
└── docs/
    ├── verification/     # probe results and transcripts (dated, one file per probe)
    └── attic/            # retired code kept for its learnings — never loaded
```

**Install model: symlink, not copy.** `bootstrap.sh` symlinks the three entries
this repo owns into `~/.hammerspoon`, leaving Hammerspoon's own `Spoons/` alone.
After that, editing the repo edits the live config — no deploy step, no second
writable copy to drift. Backs up whatever was there first, and shows a diff
before doing it. `hammerspoon/Spoons/` is gitignored.

**Consequence for auto-reload:** FSEvents does not see writes that land on a
symlink's *target*, so a watcher on `hs.configdir` would silently stop firing
after bootstrap. `init.lua` resolves its own symlink and watches the repo
directory instead, falling back to `hs.configdir` when the config is a real
directory. The load notification prints the directory being watched — that is
the check. *(Unverified as of 2026-09-01: confirm a repo-side edit still
triggers a reload.)*

### What a Cowork session can and cannot touch

| | |
|---|---|
| Sees | this repo folder, and only this folder |
| Does **not** see | `~/.hammerspoon`, System Settings, `defaults`, the Hammerspoon console |
| Can do | edit config, write docs, run shell commands **in a Linux VM**, git |
| Cannot do | run `hs`, read the tap's behaviour, click System Settings, flash the Zeal60 |

The shell a session gets is a **Linux VM with this folder mounted** — not macOS.
So `defaults read`, `hs -c`, and anything CoreGraphics is out of reach; every
such probe is a command the session writes down and the user runs, pasting the
output back. This is why `docs/verification/` exists: it is where that output
lands so the next session does not re-ask.

**Claude Code running natively on the Mac** (e.g. in the VS Code terminal) is a
different case: its shell is macOS and runs as the user, so it can read
`~/.hammerspoon` and run `defaults`. It can also drive Hammerspoon through the
fixed `hammerspoon://` endpoints in `modules/urlctl.lua`:

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
**no `hs.ipc`** (§8), so `hs -c` does not work.

**Session shape (default):**

1. Session opens with the repo connected; reads `SETUP.md` from the repo.
2. Work happens as edits to `hammerspoon/` and `docs/`.
3. Anything needing macOS becomes a **probe**: a copy-pasteable command block,
   run by the user, output filed in `docs/verification/`.
4. Every decision lands as a §8 row and, if it is a binding, a §5 row **and** a
   `keymap.lua` edit in the same commit.
5. Session ends with a commit and a mirror of `SETUP.md` into project knowledge.

**Mirror rule:** the repo copy is authoritative. Project knowledge holds a
read-only snapshot for chats that are not connected to the folder. If the two
disagree, the repo is right and the mirror is stale — never merge the mirror
back.

**Syncing the mirror** (last step of a connected session, after committing):

1. `git log -1 --format='%h %ad' --date=short`
2. Write the repo `SETUP.md` into project knowledge at path `SETUP.md`, with one
   line inserted directly under the `# ` title:
   `> **Mirror synced:** <hash> (<date>). Snapshot — the repo copy is authoritative.`
3. That line is the only difference between the two files. It is what lets a
   connected chat detect a stale mirror in one command.

A session that changes nothing does not re-sync; writing a project doc busts the
prompt cache for every chat in the project.

---

## 1. Goal & constraints

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

## 2. Environment

| Field | Value |
|---|---|
| macOS version | 27.0.1 (this machine, as of 2026-10-25; was 26.6.2 when §1–§5 were written) |
| Hardware | laptop + 2 externals (office set ≠ home set) |
| Keyboards | built-in; Zeal60 rev3 (VIA, stock caps lock) |
| Input sources | work machine: US ×2 + CH, cycled in one direction. This (personal) machine: ABC (Apple's US) + Swiss German. See §7 "Input source switching" for why work has two US layouts |
| Admin rights | **none** |
| Shell | *(fill in)* |
| Dotfiles repo | `~/Projects/claude/macos-productivity` — this repo. Whether it merges into a larger dotfiles repo later is open; §0 assumes it stands alone. |

---

## 3. Layer ownership

Each row is a layer in the input/window pipeline, ordered from lowest (closest
to hardware) to highest. **Exactly one tool owns each layer.** Anything a chat
proposes must state which layer it operates on.

| # | Layer | Owner | Status |
|---|---|---|---|
| 0 | Key remapping (caps lock, per-device rules) | **macOS System Settings → Modifier Keys** | decided, **verified** |
| 1 | Global hotkey capture | **Hammerspoon** (`hs.hotkey`, `hs.eventtap`) | decided, **nav layer built** |
| 2 | Window move & resize | **Hammerspoon** (`hs.window`, `hs.screen`) | decided |
| 3 | Space management | **native Spaces**, driven by Hammerspoon `hs.spaces` | decided, **partly unverified** |
| 4 | App launching & switching | **Spotlight** + Hammerspoon direct-launch binds | decided |
| 5 | Scripting & glue | **Hammerspoon** (same config) | decided |

Layers 1, 2 and 5 collapse into a single Lua config. That is the point: one
config tree, owned by the user, in the dotfiles repo.

**Permissions required:** Hammerspoon needs Accessibility. No daemon, no driver,
no admin. This is the entire reason the stack is shaped this way. *(Open: does
the nav layer's event tap additionally require Input Monitoring? Verify and
correct this line.)*

### Why not the obvious candidates

- **Karabiner-Elements** — ruled out. See decision log. Not a partial loss: with
  the privileged daemon unapproved, Karabiner performs *no* remapping at all,
  not even caps→Escape.
- **yabai** — ruled out. Space operations need partial SIP disable.
- **AeroSpace** — ruled out twice over: tiling is a non-goal, and a
  deliberately-suppressed tiler is worse than no tiler.
- **Rectangle / Loop** — would cover halves, but nothing else, and adds a tool
  that owns a layer Hammerspoon already owns.
- **QMK nav layer on the Zeal60** — ruled out. Would give the 60% a layer the
  built-in keyboard lacks, i.e. two divergent definitions of the same thing.
  Note this does *not* rule out firmware changes that make the two keyboards
  converge — see the 2026-08-30 firmware decision.

### Rules

> A tool may only be introduced by claiming an unowned layer, or by displacing
> the current owner of a layer (which requires updating this table).

> **Exactly one event tap may watch the fn flag**, and it is `fnlayer.lua`. Two
> taps on fn means nondeterministic ordering, double consumption, and competing
> watchdogs. Any module wanting an fn binding registers it in `keymap.lua`; it
> does not create a tap. Bindings that do not involve fn can use `hs.hotkey`,
> which needs no tap at all.

---

## 4. Keybinding namespace

### Layer 0: the caps lock key

Caps Lock is remapped in **System Settings → Keyboard → Keyboard Shortcuts →
Modifier Keys**. This pane has a **per-keyboard selector**: the mapping must be
set once for the built-in keyboard and once for the Zeal60.

Because the remap happens on the macOS side, the **Zeal60 sends a stock Caps
Lock and needs no custom firmware.** Apple's Globe is a vendor-specific HID
usage with no mainline QMK keycode and no VIA support, so firmware-side Globe
was never an option — and is not needed.

**Decided: Caps Lock → fn**

Globe and fn are the same modifier (`kCGEventFlagMaskSecondaryFn`). The Modifier
Keys pane labels the destination according to the selected keyboard: the Zeal60
selector shows **fn**, the built-in shows **🌐 Globe**. There is no choice
between them — pick whichever label the pane offers.

- Leaves `ctrl` completely untouched — no clash with macOS emacs-style text
  navigation (`^h` `^k` `^f` `^b` `^p` `^n`), no clash with readline in the
  terminal, and no clash with IntelliJ completion on `^space`.
- **Required setting:** Keyboard → "Press 🌐 key to" → **Do Nothing**. Without
  this, a lone tap switches input source *and* the synthetic tap keycode that
  Escape depends on is not emitted. Dictation has been folded into this same
  menu on 26.6.2 and is covered by the same setting.
  - This is what cost the built-in tap-to-switch-language. It is bought back
    deliberately as `caps+space` — see §5.
- Globe chord collisions (`A` Dock, `D` dictation, `F` fullscreen, `H` hide,
  `N` notifications, `Q` Quick Note) are **resolved**: the session event tap
  sees these before the system and suppresses them. Verified for `H` and `E`.
- `hs.hotkey` does **not** accept fn as a modifier. The nav layer is therefore
  built on `hs.eventtap` watching the fn flag. The Keyboard Shortcuts recorder
  will not accept fn either — same limitation, and the reason `caps+space` has
  to be translated by the tap rather than bound natively.

**Fallback: Caps Lock → Control**

Retained only in case fn handling regresses after a macOS update.

- Costs `^h`/`^k` etc. globally, including in the terminal, which is the
  expensive part.
- macOS emacs bindings *can* be disabled per-user via
  `~/Library/KeyBindings/DefaultKeyBinding.dict` (e.g. `"^h" = "noop:";`), but
  this affects Cocoa text views only — not Electron, JetBrains, or terminals.
  Mostly moot anyway, since a Hammerspoon binding shadows them.

**Escape:** tap caps alone → Escape. macOS emits a synthetic keyDown of
**keycode 179** when the Globe/fn modifier is pressed and released without being
chorded. The tap watches for that keycode rather than running a timeout
heuristic. Fires on release; vim reacts to the synthesized Escape's keydown, so
the only latency is the finger.

### Namespace reservations

| Modifier combo | Reserved for | Notes |
|---|---|---|
| `caps` (=fn) + key | **nav layer** — arrows and cursor motion | the 60% has no arrow keys; this is the whole point |
| `caps+shift` + key | nav layer with selection | falls out of modifier pass-through, no extra code |
| `alt` + key | **unallocated** | a candidate for window ops, not a decision — see §7 |
| `alt+shift` + key | **unallocated** | same |
| `ctrl` + key | **do not take** | emacs bindings, readline, IDE |
| `cmd` + key | **macOS / apps — do not take** | breaks app menus. **One deliberate exception below** |
| `cmd` + key left of `1` (`cmd+shift` reverse) | **window cycling within the app, across spaces and displays** | replaces macOS's own "Move focus to next window" (`` cmd+` ``). Bound by **physical key (keycode), not character**, because the key's keycode differs by keyboard (§7). Decided 2026-10-25, §8; not built yet |
| `hyper` (ctrl+alt+cmd+shift) | **private channel: tap → OS shortcuts** | not hand-reachable on either keyboard; used to address native shortcuts that the recorder will not let fn reach |
| leader key sequences | not adopted | |

**Convention:** *(to be fixed in the window chat, together with the choice of
modifier itself — e.g. "plain = focus, +shift = move window, +ctrl = move to
display")*

**Reserved by macOS — never bind:** `cmd+tab`, `cmd+space`, `ctrl+↑`,
`ctrl+←/→`, `cmd+shift+3/4/5`, `cmd+Q/W/H/M`. Check
System Settings → Keyboard → Keyboard Shortcuts before claiming anything else.

---

## 5. Keymap

The single table every chat must check before proposing a binding. One row per
binding, no exceptions. Machine-readable counterpart:
`hammerspoon/config/keymap.lua`, embedded in §10.

| Binding | Action | Layer | Tool | Subtopic |
|---|---|---|---|---|
| `caps` (tap) | Escape | 1 | Hammerspoon | nav — via synthetic keycode 179 on lone tap, not a timeout |
| `caps+h/j/k/l` | ← ↓ ↑ → | 1 | Hammerspoon | nav — Globe+H collision resolved, event tap wins |
| `caps+shift+h/j/k/l` | select ← ↓ ↑ → | 1 | Hammerspoon | nav — free; modifiers pass through with fn stripped |
| `caps+alt+h/l` | word ← → | 1 | Hammerspoon | nav — free, same mechanism |
| `caps+space` | cycle input source (next, one direction) | 1 | Hammerspoon | **done** — re-emits hyper+space; OS shortcut holds the layout list |

*(everything else pending the per-subtopic chats)*

**Note for the window chat:** `caps+shift+h/j/k/l` and `caps+alt+h/l` are
currently spent on selection and word motion. If window ops land on `caps`, those
collide and something has to move. That is a real cost of the modifier choice in
§7, not an afterthought.

### Known conflicts / rejected bindings

| Binding | Why rejected |
|---|---|
| `hyper` (ctrl+alt+cmd+shift) on caps | Requires Karabiner. Unavailable — no admin. Modifier Keys can only map caps to a *single* modifier. |
| `ctrl+h/j/k/l` for nav | Shadows macOS emacs bindings and readline globally. Fallback only. |
| `ctrl+←/→` | Reserved by macOS for Spaces. |
| `ctrl+space` for input source | macOS default, but clashes with IntelliJ basic completion. `ctrl` is a "do not take" row. Native shortcut moved off it. |
| `caps` tap via timeout heuristic | Unnecessary — macOS emits keycode 179 on a lone Globe tap. Also avoids spurious Escape when a fast chord outruns the timeout. |
| Double-tap `caps` for input source | Same rejected timing heuristic in another costume. |
| Anything relying on `hs.spaces` | Not rejected, but **do not commit bindings until verified** — see open questions. |

---

## 6. Subtopic status

| Subtopic | Status | Depends on | Notes |
|---|---|---|---|
| Architecture / layer ownership | **done** (2026-08-30) | — | this document |
| Nav layer (caps → Escape + arrows) | **done** (2026-08-30) | architecture | verified on both keyboards |
| Config module structure | **done** (2026-08-30) | nav layer | loader / keymap / fnlayer; §10 |
| Input source switching | **done** (2026-08-30) | nav layer | `caps+space`; three layouts, one direction |
| Repo & Cowork workflow | **done** (2026-09-01) | config module structure | §0. `bootstrap.sh` applied 2026-10-25; `~/.hammerspoon` now links into the repo |
| Window moving & resizing (halves) | **next** | architecture | primary window use case. **First question is which modifier** — see §7 |
| Displays & multi-monitor | ready | architecture | must handle office/home monitor swap |
| Space management | **blocked on verification** | `hs.spaces` test | may be dropped entirely. 2026-10-25 on 27.0.1: `allSpaces`/`windowsForSpace`/`focusedSpace`/watcher work; **`moveWindowToSpace()` returns true but does not move the window**; `missionControlSpaceNames()` returns nil |
| Window switching (focus) | **in progress** (target set 2026-10-25) | architecture | not a switcher: `` cmd+` `` cycling the app's windows **across spaces**, MRU. Findings re-verified; see §7 "Window cycling across spaces" |
| Launcher & app switching | ready | architecture | Spotlight + direct-launch binds |
| Zeal60 firmware & physical layout | ready | nav layer | modifier row parity, Esc/backtick position, QMK fn audit |
| Browser | **needs own chat** | nav layer | choice of browser, extensions, scrolling, keyboard nav |
| Per-app rules & exceptions | blocked | all above | terminal, IDE exclusions |
| Packaging into dotfiles repo | **partly done** (2026-09-01) | all above | repo + `bootstrap.sh` exist; README must carry the System Settings steps, which are *not* file-based |

---

## 7. Open questions

**Repo / workflow (new, 2026-09-01)**

- ~~`bootstrap.sh` has not been run.~~ **Done 2026-10-25.** The drift was
  comment-only in `keymap.lua`/`fnlayer.lua`, plus a live-only `winswitch.lua`
  loaded by the old `init.lua`, which is now archived in `docs/attic/` (see §8).
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
  this tap? §3 currently claims Accessibility only — verify and correct if so.
- **Layer 0 is not reproducible from the repo, and is now three GUI settings.**
  Modifier Keys (per keyboard), "Press 🌐 key to → Do Nothing", and the Input
  Sources shortcut. All stored outside the dotfiles. Documented as manual steps
  in `README.md`, re-done on every new machine *and* every new keyboard.
- **Proposed, not decided — extra nav bindings.** `caps+u/d` (page up/down,
  replacing the fn+↑/↓ the 60% cannot reach), `caps+a/e` (line start/end, with
  selection falling out of pass-through for free). Both are already expressible
  in `keymap.lua` and sit commented out there awaiting a decision and a §5 row.
- `hs.eventtap` reliability: macOS can disable an event tap under load or after a
  timeout. Watchdog and wake-watcher are in the config from day one; watch
  whether they actually fire in practice.

**Window ops — which modifier? (undecided)**

- `alt` was listed as the window modifier in earlier drafts of §4, but this was
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
       firmware** (§8 2026-08-30: there is no QMK keycode for Apple's Globe,
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
       that Escape depends on (§4), and still survives "Press 🌐 key to: Do
       Nothing".
       If (c) fails, Escape-on-tap would need a timing heuristic, which §8
       rules out. Probe before flashing anything.
  3. ~~Catching off-space windows from AX notifications.~~ **Confirmed
     2026-10-25** (`docs/verification/2026-10-25-ax-notifications-and-id-reuse.md`).
     A per-app `hs.axuielement.observer` on the application element received
     `AXTitleChanged` for a Chrome window on another space and resolved it to
     a usable handle, which `focus()` then switched to. The probe never
     enumerated that window. So the cache fills from any window that changes,
     and the gap shrinks to windows that stay completely static.
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
    `setLayout` breaks on IMEs (§8). Possibly too hard; noted, not planned.
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
  **Update 2026-10-25:** shadowing it is now decided (§8), and the binding is
  by physical key; see "Window cycling across spaces" item 2.

**Browser**

- **Browser is a subtopic of its own** — browser choice, extensions, scrolling
  behaviour, in-page keyboard navigation. Mostly application config rather than
  a layer in §3, so it may not belong in this document at all beyond the points
  where it collides with the stack. Two things it must answer: (a) does
  `caps+j/k` scroll in the browser, or does the browser want its own scroll
  binding — this is a **per-app rules** question and a genuine layer 1 concern;
  (b) does any extension take bindings that collide with §4's namespace
  reservations. Vim-style extensions in particular claim `hjkl` and `Escape`,
  both of which the nav layer now owns globally.

**Rest of stack**

- **Does `hs.spaces` work reliably on 26.6.2?** It is built on undocumented
  CoreGraphics calls and is the most likely thing to break on a macOS update.
  Needs an empirical test before any space binding is committed. If it fails,
  layer 3 has no owner and space management is dropped from scope.
- How is window state restored after a reboot / display disconnect?

---

## 8. Decision log

Append-only. Each entry: what was decided, why, and what it rules out.

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

---

## 9. Config file inventory

Repo paths are relative to `~/Projects/claude/macos-productivity`. Live paths are
what Hammerspoon reads; the arrow is the symlink `bootstrap.sh` creates.

| File | Repo path | Live path | Owns layer(s) |
|---|---|---|---|
| `init.lua` | `hammerspoon/init.lua` | → `~/.hammerspoon/init.lua` | loader only — no bindings, no logic |
| `keymap.lua` | `hammerspoon/config/keymap.lua` | → `~/.hammerspoon/config/` | bindings as data; machine-readable twin of §5 |
| `fnlayer.lua` | `hammerspoon/modules/fnlayer.lua` | → `~/.hammerspoon/modules/` | 1 — **sole owner of the fn tap** |
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

**Drift:** §5 and `keymap.lua` state the same bindings — §5 with rationale, the
Lua without. Every binding decision is a two-file edit, in one commit. Both are
embedded in this document so a chat that receives it sees both.

---

## 10. Current config

Nav layer verified working on both keyboards, 2026-08-30. Split into modules
2026-08-30. Moved into the repo and given a symlink-aware config watcher
2026-09-01. Linked live by `bootstrap.sh` 2026-10-25, when `urlctl.lua` was
also added; auto-reload through the link was verified the same day, and
`caps+hjkl`, lone-tap Escape and `caps+space` were re-verified by hand on the
linked config (2026-10-25).

### `hammerspoon/init.lua` → `~/.hammerspoon/init.lua`

```lua
-- ~/.hammerspoon/init.lua — loader only. No bindings live here.
--
-- Bindings:  config/keymap.lua
-- Mechanism: modules/fnlayer.lua
--
-- This file is a SYMLINK to <repo>/hammerspoon/init.lua (see bootstrap.sh).
--
-- Manual System Settings steps this config depends on (SETUP.md §9):
--   1. Keyboard → Modifier Keys → Caps Lock = fn/Globe, set PER KEYBOARD
--   2. Keyboard → "Press 🌐 key to" → Do Nothing        (Escape depends on this)
--   3. Keyboard Shortcuts → Input Sources → "Select next source in Input menu"
--      = ⌃⌥⇧⌘Space, and the "previous source" row CLEARED, not just unchecked

-- Auto-reload on config change.
--
-- hs.configdir is ~/.hammerspoon, whose entries are symlinks into the repo.
-- FSEvents reports on the directory it is given and does NOT see writes that
-- land on a symlink's target, so watching hs.configdir alone would silently
-- stop auto-reloading once bootstrap.sh has run. Resolve this file's own link
-- and watch the repo directory instead; fall back to hs.configdir when the
-- config is a real directory (e.g. before bootstrap, or on a copy install).
local function configRoot()
  local this = debug.getinfo(1, "S").source:sub(2)      -- ~/.hammerspoon/init.lua
  local target = hs.fs.symlinkAttributes(this, "target")
  if target then
    if target:sub(1, 1) ~= "/" then                     -- relative link
      target = hs.configdir .. "/" .. target
    end
    return target:match("^(.*)/[^/]+$")
  end
  return hs.configdir
end

local root = configRoot()

-- Watcher before any module loads: if one errors, the rest of this file
-- never runs, and a fix should still reload without a trip to the menu.
configWatcher = hs.pathwatcher.new(root, function(paths)
  for _, p in ipairs(paths) do
    if p:sub(-4) == ".lua" then hs.reload() return end
  end
end)
configWatcher:start()

-- Diagnostics first, so every module's load-time warnings reach .live/log.txt.
-- .live/ sits at the repo root, outside the watched directory, so writing it
-- cannot trigger a reload. Gitignored. See modules/diag.lua.
local diag = require("modules.diag")
diag.setup(root .. "/../.live")
diag.logger("init").i("loading, watching %s", root)

local keymap  = require("config.keymap")
local fnlayer = require("modules.fnlayer")

fnlayer.start(keymap.fn)

-- Optional, gitignored probe (probes/README.md). Caught, so a broken probe
-- cannot take the config down with it.
local probe
local probePath = root .. "/probes/active.lua"
if hs.fs.attributes(probePath) then
  local ok, res = xpcall(dofile, debug.traceback, probePath)
  if ok then probe = res else diag.logger("probe").e("load failed: %s", res) end
end

-- hammerspoon://reload, ://status, ://probe. Parameterless endpoints in
-- place of hs.ipc (SETUP.md §8). Started last so the load-time status sees
-- every module's provider.
require("modules.urlctl").start({ root = root, probe = probe })

hs.notify.show("Hammerspoon", "", "config loaded — " .. root)
```

### `hammerspoon/config/keymap.lua`

```lua
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
}
```

### `hammerspoon/modules/fnlayer.lua`

```lua
-- modules/fnlayer.lua — sole owner of the fn/Globe event tap (SETUP.md §3, layer 1).
--
-- INVARIANT: exactly one event tap may watch the fn flag. Two taps means
-- nondeterministic ordering and double consumption. Anything fn-based
-- registers here via config/keymap.lua. Anything NOT fn-based can use
-- hs.hotkey instead, which needs no tap.

local diag = require("modules.diag")
local log  = diag.logger("fnlayer")

local M = {}

-- Synthetic keyDown macOS emits on a lone, unchorded Globe tap. Undocumented;
-- only emitted while Keyboard → "Press 🌐 key to" is Do Nothing.
local GLOBE_TAP_KEYCODE = 179

local eventTypes = hs.eventtap.event.types
local PASSABLE   = { "cmd", "alt", "ctrl", "shift" }  -- note: fn deliberately absent

-- Modifiers you were actually holding, minus fn. Dropping fn is what stops
-- fn+← becoming Home, and is also the loop guard: the replacement carries no
-- fn, so this tap will not re-match it.
local function stripFn(flags)
  local mods = {}
  for _, m in ipairs(PASSABLE) do
    if flags[m] then table.insert(mods, m) end
  end
  return mods
end

local function merge(a, b)
  local seen, out = {}, {}
  for _, list in ipairs({ a or {}, b or {} }) do
    for _, m in ipairs(list) do
      if not seen[m] then
        seen[m] = true
        table.insert(out, m)
      end
    end
  end
  return out
end

-- Resolve key NAMES to keycodes once at load, and complain loudly about a bad
-- spec rather than silently doing nothing at 3pm on a Tuesday.
local function compile(keymap)
  local byKeycode = {}
  for name, spec in pairs(keymap) do
    local kc = hs.keycodes.map[name]
    if not kc then
      log.w("unknown source key %q — binding skipped", name)
    elseif not (spec.key or spec.action) then
      log.w("%q has neither key nor action — skipped", name)
    elseif spec.key and not hs.keycodes.map[spec.key] then
      log.w("%q → unknown destination key %q — skipped", name, spec.key)
    else
      for _, m in ipairs(spec.mods or {}) do
        if m == "fn" then
          error(("fnlayer: %q has fn in mods — would loop"):format(name))
        end
      end
      byKeycode[kc] = spec
    end
  end
  return byKeycode
end

function M.start(keymap)
  if M.tap then M.tap:stop() end
  local bindings = compile(keymap)

  M.tap = hs.eventtap.new(
    { eventTypes.keyDown, eventTypes.keyUp },
    function(e)
      local kc    = e:getKeyCode()
      local flags = e:getFlags()
      local down  = (e:getType() == eventTypes.keyDown)

      -- Lone tap → Escape. Stays in mechanism rather than the keymap: 179
      -- arrives as a keyDown with no matching keyUp, so it cannot use the
      -- replacement-event path below and needs keyStroke to synthesize both.
      if kc == GLOBE_TAP_KEYCODE then
        if down then hs.eventtap.keyStroke({}, "escape", 0) end
        return true
      end

      if not flags.fn then return false end
      local spec = bindings[kc]
      if not spec then return false end

      if spec.action then
        if down then spec.action() end
        return true
      end

      local mods
      if spec.passthrough == false then
        mods = spec.mods or {}
      else
        mods = merge(spec.mods, stripFn(flags))
      end

      -- Delete the original, post a replacement. Handling keyUp identically
      -- means apps never see an unmatched keyDown, and OS autorepeat drives
      -- repeat for free.
      return true, { hs.eventtap.event.newKeyEvent(mods, spec.key, down) }
    end
  )
  M.tap:start()

  diag.provide("fnlayer", function()
    local names = {}
    for kc in pairs(bindings) do names[#names + 1] = hs.keycodes.map[kc] or tostring(kc) end
    table.sort(names)
    return { tapEnabled = M.tap:isEnabled(), bindings = names }
  end)

  -- macOS disables taps under load, after timeouts, and across sleep.
  if M.watchdog then M.watchdog:stop() end
  M.watchdog = hs.timer.doEvery(5, function()
    if M.tap and not M.tap:isEnabled() then
      log.w("tap disabled — restarting")
      M.tap:start()
    end
  end)

  if M.wakeWatcher then M.wakeWatcher:stop() end
  M.wakeWatcher = hs.caffeinate.watcher.new(function(evt)
    if evt == hs.caffeinate.watcher.systemDidWake
      or evt == hs.caffeinate.watcher.screensDidUnlock then
      if M.tap and not M.tap:isEnabled() then M.tap:start() end
    end
  end)
  M.wakeWatcher:start()
end

function M.stop()
  if M.tap then M.tap:stop() end
  if M.watchdog then M.watchdog:stop() end
  if M.wakeWatcher then M.wakeWatcher:stop() end
end

return M
```

### `hammerspoon/modules/urlctl.lua`

```lua
-- modules/urlctl.lua — fixed hammerspoon:// control endpoints (SETUP.md §0, §8).
--
-- A narrow interface in place of hs.ipc. NOT a security boundary (SETUP.md
-- §8): anything running as this user can already write the config, which
-- this file is part of. The narrowness is about keeping the surface small
-- and predictable, not about keeping an attacker out.
--
--   open -g hammerspoon://reload   reload the config
--   open -g hammerspoon://status   rewrite .live/status.json and .live/console.txt
--   open -g hammerspoon://probe    call run() on probes/active.lua, if loaded
--
-- Both files are also written on every load, so a changed `loaded` time is how
-- a caller confirms a reload actually happened. Module state comes from
-- diag.provide(); see modules/diag.lua.
--
-- RULE: endpoints take no params. Code to run comes from files in the repo
-- (probes/), which are in git or deliberately gitignored, never from the URL.

local diag = require("modules.diag")
local log  = diag.logger("urlctl")

local M = {}

local function writeStatus(ctx, reason)
  local status = {
    reason        = reason,
    loaded        = M.loadedAt,
    written       = os.date("%Y-%m-%dT%H:%M:%S"),
    hsVersion     = hs.processInfo.version,
    configdir     = hs.configdir,
    watching      = ctx.root,
    accessibility = hs.accessibilityState(),
    modules       = diag.collect(),
  }
  local ok, json = pcall(hs.json.encode, status, true)
  if not ok then
    -- a provider returned something unencodable; still say so in the file
    json = hs.json.encode({ reason = reason, written = status.written,
                            error = "status not encodable: " .. tostring(json) }, true)
  end
  local path = diag.dir .. "/status.json"
  local f, err = io.open(path, "w")
  if not f then return log.e("cannot write %s: %s", path, err) end
  f:write(json, "\n")
  f:close()
  diag.dumpConsole()
end

local function runProbe(ctx)
  local probe = ctx.probe
  if not (probe and probe.run) then return log.w("probe requested, none loaded") end
  local ok, err = xpcall(probe.run, debug.traceback)
  if not ok then log.e("probe run failed: %s", err) end
  writeStatus(ctx, "probe")
end

-- ctx: { root = watched dir, probe = loaded probe table or nil }. Call after
-- every other module has started, so the load-time status includes their
-- providers.
function M.start(ctx)
  M.loadedAt = os.date("%Y-%m-%dT%H:%M:%S")
  hs.urlevent.bind("reload", function() log.i("reload requested"); hs.reload() end)
  hs.urlevent.bind("status", function() writeStatus(ctx, "requested") end)
  hs.urlevent.bind("probe",  function() runProbe(ctx) end)
  writeStatus(ctx, "load")
end

return M
```

### `hammerspoon/modules/diag.lua`

```lua
-- modules/diag.lua — what a shell session can read about the running config.
--
-- Everything lands in <repo>/.live/ (gitignored), written by Hammerspoon and
-- read by whoever is debugging. Output only: nothing here reads input.
--
--   log.txt      timestamped lines from diag.logger(), kept across reloads
--   console.txt  the Hammerspoon console, dumped on load and on ://status
--   status.json  written by urlctl; includes every provider registered here
--
-- Usage in a module:
--   local diag = require("modules.diag")
--   local log  = diag.logger("winswitch")
--   log.i("cached %d windows", n)
--   diag.provide("winswitch", function() return { cache = ... } end)
--
-- Providers must return plain data (tables, strings, numbers, booleans) that
-- hs.json can encode. They run inside pcall, so one bad provider shows up as an
-- error string in status.json rather than breaking the dump.

local M = { providers = {} }

local MAX_LOG = 1024 * 1024   -- rotate to log.txt.1 past this

function M.setup(dir)
  M.dir = dir
  hs.fs.mkdir(dir)            -- returns nil if it already exists; that is fine
end

local function append(line)
  if not M.dir then return end
  local path = M.dir .. "/log.txt"
  local attr = hs.fs.attributes(path)
  if attr and attr.size > MAX_LOG then os.rename(path, path .. ".1") end
  local f = io.open(path, "a")
  if f then f:write(line, "\n"); f:close() end
end

-- Prints to the console as well, so nothing is lost if the file is unwritable.
function M.logger(name)
  local function level(tag)
    return function(fmt, ...)
      local msg = select("#", ...) > 0 and fmt:format(...) or fmt
      local line = ("%s %s %s: %s"):format(os.date("%Y-%m-%dT%H:%M:%S"), tag, name, msg)
      print(line)
      append(line)
    end
  end
  return { i = level("I"), w = level("W"), e = level("E"), d = level("D") }
end

function M.provide(name, fn) M.providers[name] = fn end

function M.collect()
  local out = {}
  for name, fn in pairs(M.providers) do
    local ok, v = pcall(fn)
    out[name] = ok and v or ("provider error: " .. tostring(v))
  end
  return out
end

-- The console is where errors from callbacks end up, so this is how a shell
-- session sees a stack trace.
function M.dumpConsole()
  if not M.dir then return end
  local f = io.open(M.dir .. "/console.txt", "w")
  if f then f:write(hs.console.getConsole() or "", "\n"); f:close() end
end

return M
```

**Why it is shaped this way:**

- Returning `true, { repl }` deletes the original and posts a replacement rather
  than consuming and firing a separate keystroke. Handling `keyUp` the same way
  means apps never see an unmatched keyDown, and **OS autorepeat drives repeat
  for free**.
- `stripFn` is what stops fn+← becoming Home. It also yields `caps+shift+l`
  (select-right) and `caps+alt+l` (word-right) with no extra bindings, since
  surviving modifiers ride along on the arrow.
- Stripping fn is also the loop guard: the replacement carries no fn, so the tap
  will not re-match it. `passthrough = false` entries are guarded instead by the
  `compile` check that rejects fn in `mods`.
- `caps+space` handles keyUp too, for the same reason as the arrows, and so no
  stray space reaches the focused field.
- `caps+space` deliberately holds no knowledge of which layouts exist. The OS
  shortcut cycles the enabled ones in Input-menu order, so adding or removing a
  layout needs no config change.
- `compile` warns and skips rather than aborting, so one typo does not take the
  whole nav layer down with it. **Check the Hammerspoon console after editing
  the keymap** — a skipped binding looks identical to a broken one.
- `configRoot()` in `init.lua` exists only because of the symlink install (§0).
  Under a copy install it is a no-op that returns `hs.configdir`.
- `urlctl.lua` endpoints take no parameters on purpose (§8). `.live/` sits at
  the repo root, outside the watched `hammerspoon/` directory, so writing it
  cannot trigger a reload loop. If `configRoot()` ever falls back to
  `hs.configdir`, it lands in `~/.live/` instead, so a stale `.live/` in the
  repo is itself a symptom.
- The watcher starts **before** any module loads. A module that errors stops
  the rest of `init.lua`, and a fix must still be able to reload.
- New modules log through `diag.logger(name)`, not bare `print`/`hs.printf`, so
  the line reaches `.live/log.txt` too.
