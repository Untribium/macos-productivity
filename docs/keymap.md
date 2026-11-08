# Keymap

The contract every component binds into: which tool owns which layer of the
input pipeline, which modifier combinations are reserved for what, and the
keymap itself. **Check the Keymap for a collision before proposing any
binding**, whichever component it is for.

A binding change is one commit touching `hammerspoon/config/keymap.lua` (the
machine-readable twin) and the Keymap table below, plus a decision-log entry in
the owning component's `DESIGN.md` if it is a real choice.

## Layer ownership

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
| 6 | Keyboard-driven overlay UI (panels: launcher, todo) | **overlay app** (native Swift, `overlay/`); opened via hyper chords re-emitted by layer 1 | **spike** (2026-11-08) |

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

## Keybinding namespace

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
    deliberately as `caps+space` — see Keymap.
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
| `alt` + key | **unallocated** | a candidate for window ops, not a decision — see `hammerspoon/DESIGN.md` › Open questions |
| `alt+shift` + key | **unallocated** | same |
| `ctrl` + key | **do not take** | emacs bindings, readline, IDE |
| `cmd` + key | **macOS / apps — do not take** | breaks app menus. **One deliberate exception below** |
| `cmd` + key left of `1` (`cmd+shift` reverse) | **window cycling within the app, across spaces and displays** | replaces macOS's own "Move focus to next window" (`` cmd+` ``). Bound by **physical key (keycode), not character**, because the key's keycode differs by keyboard (`hammerspoon/DESIGN.md` › Open questions). Decided 2026-10-25, `hammerspoon/DESIGN.md` › Decision log; not built yet |
| `hyper` (ctrl+alt+cmd+shift) | **private channel: tap → OS shortcuts** | not hand-reachable on either keyboard; used to address native shortcuts that the recorder will not let fn reach |
| leader key sequences | not adopted | |

**Convention:** *(to be fixed in the window chat, together with the choice of
modifier itself — e.g. "plain = focus, +shift = move window, +ctrl = move to
display")*

**Reserved by macOS — never bind:** `cmd+tab`, `cmd+space`, `ctrl+↑`,
`ctrl+←/→`, `cmd+shift+3/4/5`, `cmd+Q/W/H/M`. Check
System Settings → Keyboard → Keyboard Shortcuts before claiming anything else.

---

## Keymap

The single table every chat must check before proposing a binding. One row per
binding, no exceptions. Machine-readable counterpart:
`hammerspoon/config/keymap.lua`.

| Binding | Action | Layer | Tool | Subtopic |
|---|---|---|---|---|
| `caps` (tap) | Escape | 1 | Hammerspoon | nav — via synthetic keycode 179 on lone tap, not a timeout |
| `caps+h/j/k/l` | ← ↓ ↑ → | 1 | Hammerspoon | nav — Globe+H collision resolved, event tap wins |
| `caps+shift+h/j/k/l` | select ← ↓ ↑ → | 1 | Hammerspoon | nav — free; modifiers pass through with fn stripped |
| `caps+alt+h/l` | word ← → | 1 | Hammerspoon | nav — free, same mechanism |
| `caps+space` | cycle input source (next, one direction) | 1 | Hammerspoon | **done** — re-emits hyper+space; OS shortcut holds the layout list |
| `caps+Return` | toggle the overlay panel | 1 | Hammerspoon → overlay app | **spike** (2026-11-08) — re-emits hyper+Return, which `overlay/` registers as a Carbon hotkey (no permissions needed). Bound on `padenter`: macOS delivers fn+Return as keypad Enter (keycode 76), so a `return` binding never matches |
| `` cmd+` `` (key left of 1: keycode 50 ANSI, 10 ISO; both bound) | cycle the frontmost app's windows across spaces/displays, MRU, **like cmd+tab**: each press selects, releasing cmd switches once; a quick tap toggles to the last window; holding (`overlayDelay`, 0.3 s) or a 2nd press shows a glass-style list (the revealing press does not move the selection) (title, desktop) with the selection (a flat **system-accent** pill; text white or dark by WCAG contrast; accent and light/dark read on every draw) fixed at screen centre and the list sliding under it; the current window is selectable; `cmd+shift` reverses, Escape cancels | 2 | Hammerspoon `hs.hotkey` + `hs.canvas` | **PoC** (2026-10-25) — `modules/wincycle.lua`; `overlay = false` in `keymap.lua` gives the plain toggle |

*(everything else pending the per-subtopic chats)*

**Note for the window chat:** `caps+shift+h/j/k/l` and `caps+alt+h/l` are
currently spent on selection and word motion. If window ops land on `caps`, those
collide and something has to move. That is a real cost of the modifier choice in
`hammerspoon/DESIGN.md` › Open questions, not an afterthought.

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
