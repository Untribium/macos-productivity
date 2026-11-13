# Backlog

Work that no component owns yet. When an item is picked up, it moves into the
owning component's `DESIGN.md` (a new component claims its layer in
`docs/keymap.md` first, if it has one) and leaves this file.

Most of it comes from the old setup scripts in `~/Data/tools/setup/`
(`keyboard/`, `ui/`, `shell/`, `applications/`, `samples/`, from 2023–24),
reviewed 2026-11-10. What was dropped is listed at the end, so it isn't
proposed again.

## Global bootstrap

One command-line entry point for a new machine. It asks which modules to
enable on this machine, survey-style (e.g. Citrix only on work machines), then
runs them.

- Each module is self-contained: dry run by default, `--apply` to write, and a
  one-line description that the survey shows.
- `bootstrap.sh` (Hammerspoon symlinks) and `install-layout.sh` (branch
  `machine-setup`) already follow this shape.
- Open: where the per-machine answers live, so a re-run doesn't ask again.

## macOS defaults module

Preferences kept from the old scripts. Plain `defaults write`, no admin:

| Setting | Command | Old script |
|---|---|---|
| Fast key repeat | `defaults write -g InitialKeyRepeat -int 10`, `defaults write -g KeyRepeat -int 1` (faster than the Settings slider allows) | `keyboard/increase-key-repeat.sh` |
| Hold repeats, no accent picker | `defaults write -g ApplePressAndHoldEnabled -bool false` | `keyboard/disable-character-picker.sh` |
| Tap-to-click | `defaults -currentHost write com.apple.mouse.tapBehavior -int 1` | `keyboard/enable-tap-to-click.sh` |
| Dock out of the way | `defaults write com.apple.dock autohide -bool true`, `autohide-delay -float 5`, then `killall Dock` | `ui/disable-dock.sh` |

To probe before automating (README step 3 is manual until then):

- **Caps Lock → fn, per keyboard.** The old `keyboard/map-caps-to-esc.sh`
  wrote the Modifier Keys mapping directly:
  `defaults -currentHost write -g com.apple.keyboard.modifiermapping.<vendor>-<product>-0 -array-add <dict with HIDKeyboardModifierMappingSrc/Dst>`,
  with vendor and product IDs from `system_profiler`. It did caps → Esc and
  took effect after the next login. Unknowns: the destination value for fn,
  whether it still works on 26/27, and finding the Zeal60's IDs.
- **"Press 🌐 key to" → Do Nothing.** Believed to be `AppleFnUsageType` in
  `com.apple.HIToolbox` (0 = do nothing). Unverified.

The keyboard-layout install on branch `machine-setup` (`keyboard/install-layout.sh`,
`US (ISO-safe).keylayout`) belongs alongside. It supersedes the old `hidutil`
tilde swap.

## Shell

Wanted: a shell setup like the old one. The old one was the grml zshrc with
`ZDOTDIR=~/.zsh` plus `shell/resources/zshrc.local`:

- prompt: fixed-width path, git ahead/behind, per-type file counts, stashes
- vi-mode with cursor shapes, `ctrl+j/k` history prefix search, hjkl in
  completion menus, yank to clipboard
- zsh-autosuggestions (`ctrl+l` / `shift+tab` accept a word), completions for
  brew, docker, kubectl, terraform, aws, 1password
- aliases, `iv` (pipe a command's output into nvim)

Needs a spike first: which shell, and which config preset (grml, a framework,
or none). Note for `docs/keymap.md`: the old config binds
`ctrl+h/j/k/l/p` shell-locally, inside the `ctrl` "do not take" row.

- **Superseded (user, 2026-11-13):** the `ctrl+j/k` bindings for history and
  menus, in the shell, the vim command line and IntelliJ: the caps nav layer
  gives arrows everywhere.
- **Review the rest one by one** in a separate session, combining both
  machines. Snapshots of the live vim and zsh config, one per machine:
  `docs/verification/2026-11-13-dotfiles-work-old.md`; work-new still to do.
  The vimrc (shared by vim, neovim and IdeaVim) belongs in the same review.

## IntelliJ

IdeaVIM plugin, `~/.ideavimrc` (the old one sourced a `~/.vim/vimrc` that was
never set up), `ctrl+j/k` for up/down in lists. Deferred until IntelliJ is
installed and the defaults prove annoying. Old script:
`applications/intellij-community.sh`.

## Bluesnooze / Cursorcerer replacements

Both are wanted. Prefer zero dependencies if simple enough:

- **Bluesnooze** (Bluetooth off while asleep): Hammerspoon's sleep/wake
  watcher (`hs.caffeinate.watcher`) runs a JXA one-shot via `osascript` that
  calls IOBluetooth's private power function
  (`IOBluetoothPreferenceSetControllerPowerState`). Needs a probe: whether JXA
  can bind that function, and whether it needs a permission.
- **Cursorcerer** (hide the cursor after 5 s idle). What the binary does
  (from `nm -u` and `strings`, 2026-11-10): one private call,
  `CGSSetConnectionProperty(_CGSDefaultConnection(), conn,
  "SetsCursorInBackground", kCFBooleanTrue)`, so macOS honours hide requests
  from a non-frontmost process; then public `CGDisplayHideCursor` /
  `CGDisplayShowCursor` on `CGMainDisplayID()`, with `CGCursorIsVisible`.
  Idle detection is an `NSTimer` (probably polling the mouse via `NSEvent`);
  the toggle hotkey is Carbon `RegisterEventHotKey`. The hidden state belongs
  to the process, so something must stay running. Zero-dependency candidate:
  a long-running JXA script under a LaunchAgent, binding those functions with
  `ObjC.bindFunction` and polling. Hammerspoon cannot call arbitrary C. Needs a
  probe: whether JXA can bind the private CGS symbols, and whether a
  never-exiting `osascript` behaves under launchd. Fallback: keep the real app
  (`defaults write com.doomlaser.cursorcerer idleHide -float 5`).

## Reference: hidutil + LaunchAgent

The old `keyboard/swap-tilde.sh` and `samples/autostart-example.sh` re-applied
a `hidutil property --set '{"UserKeyMapping":[…]}'` remap at every login via a
LaunchAgent in `~/Library/LaunchAgents`, no admin. This is the mechanism the
open "firmware caps → Esc, OS Esc → fn" idea needs (`hammerspoon/DESIGN.md` ›
Open questions).

## Dropped from the old setup

- `keyboard/map-caps-to-esc.sh`: superseded by caps → fn plus tap-for-Escape
  in `fnlayer.lua`.
- `keyboard/swap-tilde.sh` (`hidutil` § ↔ \`): superseded by the
  `US (ISO-safe)` layout.
- `keyboard/shortcuts/window-tiling.sh` (`NSUserKeyEquivalents` for Zoom /
  Move Left / Right): window layer 2 belongs to Hammerspoon.
- `ui/configure-workspaces.sh` (`mru-spaces false`,
  `AppleSpacesSwitchOnActivate true`): not wanted.
- `shell/set-terminal-theme.sh` (Afterglow): not wanted.
- `applications/*.sh` (brew installs): Homebrew's installer and `java.sh` need
  admin, which conflicts with the no-admin premise.
