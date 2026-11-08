# Overlay — design

Layer 6 of `docs/keymap.md`: a keyboard-driven, Spotlight-style overlay
framework (`OverlayKit`), and apps built on it, the first being a todo app.
Build and test steps are in `README.md` next to this file.

**Status:** spike done (2026-11-08). The spike app works on the home machine;
the native route is confirmed buildable on all three machines. Todo app design
is next.

---

## Goal & constraints

**Goal:** panels that open on a hotkey over whatever you are doing, take the
keyboard, and get out of the way: Spotlight, or Claude's quick entry. Not an
app you switch to.

- **Feel:** the app you were in stays active, menu bar and all. Escape or a
  click elsewhere closes the panel and focus is back where it was.
- **Keyboard first:** everything reachable without the mouse.
- **No admin, no special permissions:** same rule as the rest of the repo. The
  spike needs neither Accessibility nor Screen Recording; keep it that way
  unless a feature truly needs one, and log the decision.
- **Machines:** home (flurry), the old work machine (Jamf) for about another
  week, the new work machine (Intune). Each one builds from source.
- **Sharing** outside this repo is not a goal now, but should stay possible.

**Non-goals (for now):** a general launcher replacing Spotlight (layer 4 stays
Spotlight); syncing todo data across machines through anything but files.

---

## Architecture

- **`OverlayKit`** (library): `OverlayPanel` (non-activating `NSPanel`,
  `NSGlassEffectView`, all spaces and full-screen apps), `HotKey` (Carbon
  `RegisterEventHotKey`), `ChooserView` (SwiftUI filter-as-you-type list).
  Knows nothing about any app.
- **Apps** depend on `OverlayKit`, never the other way round.
  `OverlaySpike` lives in this package; the todo app will be its own package
  in `todo/`, depending on `../overlay`.
- **Triggering:** Hammerspoon's fn layer re-emits `caps+<key>` as
  `hyper+<key>`, and the app registers that as a Carbon hotkey. Apps also take
  a URL scheme for scripting.
- **Build:** SwiftPM with the Command Line Tools only, no Xcode.
  `scripts/build-app.sh` wraps the binary in an `.app`, signs it ad hoc, and
  with `--install` copies it to `~/Applications`.

---

## Open questions

**Intune on the new work machine (not tested yet).** The spike builds and runs
there; what Intune might restrict only shows with the real app:

- *Login items:* enable Launch at Login from the menu bar; the status must read
  `enabled`, not `requires approval`. Check System Settings → General → Login
  Items & Extensions, then relog: the app must start on its own.
- *Defender or another EDR* may flag, quarantine or delete an ad-hoc signed app
  later rather than block it at launch. Is it still there and working after a
  day or two? `command -v mdatp falconctl`; with Defender, `mdatp threat list`.
- *What is enforced:* `system_profiler SPConfigurationProfileDataType` lists
  the profiles without admin. Look for `com.apple.servicemanagement` (managed
  login items), `com.apple.TCC.configuration-profile-policy` (privacy grants),
  `com.apple.syspolicy` and `com.apple.applicationaccess`.
- Not at risk: the Carbon hotkey and the URL scheme. MDM has no lever on either.

**Citrix.** Does the hotkey fire while Citrix Viewer has focus, and does the
panel show over a full-screen Citrix session? Deferred to its own session; it
touches the existing Citrix modules too.

**Todo app:** designed in `todo/DESIGN.md`. What it needs from `OverlayKit`
beyond the spike: a capture panel (single field), editing in place, and
per-item key handling in the list.

**Visual polish** (later, with the real UI): a magnifier in the search field,
icons in rows, a softer selection than the accent pill (as Spotlight does).

---

## Decision log

Append-only. Each entry: what was decided, why, and what it rules out.

| Date | Decision | Rationale | Rules out |
|---|---|---|---|
| 2026-11-08 | **Native Swift (AppKit + SwiftUI), not Hammerspoon** | A todo app outgrows `hs.chooser` and `hs.canvas`, and `hs.webview` means two runtimes and a bridge. Hammerspoon runs one Lua runtime that also hosts the fn layer's event tap, so a busy UI there can stall the keyboard; config reloads also wipe UI state. Native gives a real non-activating panel, real text input, blur without Screen Recording, its own process, and a shareable app. | `hs.webview`/`hs.canvas` UIs for this component |
| 2026-11-08 | One repo, by component; the todo app is a separate package later | The overlay binds into the same keyboard namespace as Hammerspoon. Splitting repos is cheap later (`git subtree split`). | Separate repos for framework, todo and shortcuts, for now |
| 2026-11-08 | **Build on each machine** from source with the Command Line Tools | All three machines build and run an ad-hoc signed binary (`docs/verification/*-overlay-env-*.md`). Built locally, it carries no quarantine flag, so Gatekeeper does not assess it. No Santa anywhere. | Copying built apps between machines; requiring Xcode |
| 2026-11-08 | Floor: Swift 6.2 tools, macOS 26 deployment target, main-actor default isolation | Swift 6.2 / SDK 26.2 is the oldest toolchain in use (old work machine). macOS 26 is the oldest OS. | APIs newer than the 26.2 SDK while the old work machine is in use |
| 2026-11-08 | Hotkey: **Carbon `RegisterEventHotKey`** on hyper chords, re-emitted from the fn layer (`caps+Return` → hyper+Return) | Needs no permission, unlike an event tap. Carbon cannot take fn, and Hammerspoon's fn layer already owns fn, so it forwards on the private hyper channel, like `caps+space`. Bound on `padenter`: macOS delivers fn+Return as keypad Enter (`docs/verification/2026-11-08-fn-return-is-padenter.md`). | An event tap in the overlay app; a second tap on fn |
| 2026-11-08 | Panel: non-activating `NSPanel`, `.regular` glass by default | Matches Spotlight: frosted and nearly opaque over dark content. `.clear` shows the background through and costs text contrast; kept as a menu toggle in the spike. | Activating the app to show UI |
