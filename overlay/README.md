# overlay

A keyboard-driven, Spotlight-style overlay for macOS, in Swift. **Spike stage.**

- `Sources/OverlayKit/`: the framework. A non-activating glass panel
  (`OverlayPanel`), a Carbon global hotkey (`HotKey`, no permissions needed)
  and a filter-as-you-type list (`ChooserView`).
- `Sources/OverlaySpike/`: a running-apps launcher built on it, to test the
  feel on each machine.
- `probes/env-check.sh`: can this machine build and run it? One report per
  machine in `docs/verification/`.

## Build and run

```sh
overlay/probes/env-check.sh             # once per machine
overlay/scripts/build-app.sh --install  # build, copy to ~/Applications, launch
```

Needs the Command Line Tools only (Swift 6.2 or newer), no Xcode, no admin.
Quit from the menu bar icon.

## Spike checklist (per machine)

Watch the log while testing:
`/usr/bin/log stream --predicate 'subsystem == "overlay-spike"'`
(plain `log` is a zsh builtin).

1. **Hotkey:** `caps+Return` (Hammerspoon re-emits hyper+Return) opens and
   closes the panel. The menu bar menu shows whether the hotkey registered.
2. **Overlay feel:** the menu bar keeps showing the app you were in; typing
   filters; arrows or ctrl+n/p move; Return opens the app; Escape closes.
3. **Focus return:** after Escape, keep typing: it lands in the app you were in.
   The log's `hidden; frontmost:` line should name that app.
4. **Click outside** closes the panel.
5. **Full screen:** the panel shows over a full-screen app, Citrix Viewer included.
6. **Under Citrix:** `caps+Return` fires while Citrix Viewer has focus.
7. **URL scheme:** `open -g overlay-spike://toggle` toggles it.
8. **Login item:** menu → Launch at Login; the status line reads `enabled`, and
   it starts after logging out and in.
