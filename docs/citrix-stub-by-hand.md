# Citrix desktop stub, built by hand

For a machine where Citrix Workspace does **not** create the per-desktop app in
`~/Applications` (README step 6.1). Everything below the findings is
**untested**: nobody has run it on a machine without a Workspace-made stub yet.
Record the outcome in `docs/verification/` once someone has.

Placeholders: `<STORE_HOST>` store hostname, `<STORE_PATH>` store path on that
host (the part before `/discovery`), `<GATEWAY_URL>` external gateway,
`<STORE_CODE>` the store's code in the unique name, `<DESKTOP>` published
desktop name, `<ID>` the `$P<number>` suffix. The concrete values for the work
setup are in the README.

## What Workspace does (read from a working machine)

- The stub is a copy of Workspace's own template, with two edits:
  - `Contents/Info.plist`: `CFBundleIdentifier` =
    `com.citrix.XenDesktopAlias-<STORE_CODE>.<DESKTOP-without-spaces>$P<ID>`,
    `CFBundleName` = the display name.
  - `Contents/Resources/Citralias.plist`: tells the stub what to launch.
- Template location:
  `/Applications/Citrix Workspace.app/Contents/Frameworks/CitrixWorkspaceApps.framework/Versions/<version>/Helpers/CitrixWorkspaceApps/Templates/DockApplication.app`
- `Citralias.plist` keys and values:

  | Key | Value |
  |---|---|
  | `Access Gateway Auth Type`, `Access Gateway Type` | `none` |
  | `Citrix Application Type` | `Desktop` |
  | `Citrix Content Address`, `Citrix Description`, `Citrix Publisher Name` | empty string |
  | `Citrix Server Unique Application Name` | `<STORE_CODE>.<DESKTOP> $P<ID>` |
  | `Delivery Services Launch URL` | `https://<STORE_HOST>/<STORE_PATH>/resources/v2/<B64>/launch/ica` |
  | `External Store URL` | `<GATEWAY_URL>` |
  | `Internal Store URL` | `https://<STORE_HOST>/<STORE_PATH>/discovery` |
  | `Properties` | dict of store codes, each `true` (one for the store, plus sibling stores) |
  | `SchemaVersion` | `1` (integer) |
  | `Store Name` | `<STORE_HOST>` |
  | `cloneName` | `<DESKTOP>.app` |

- `<B64>` is the unique application name, base64, with `=` padding written as
  `-`. Seen with `+`/`/`-free input only, so the URL-safe mapping of those two
  is unconfirmed.
- The `$P<ID>` is assigned by the store per published resource. Several stubs
  can share a display name with different IDs, so copy the ID from a working
  machine or a Workspace-made stub; do not guess.
- Workspace prefs (`defaults read com.citrix.receiver.nomas`) hold
  `StoreInfo.<store>.appShortcutSkippedState` (seen: `notskipped`), and the
  binary references `didSkipAppShortcutCreation` and
  `shouldAddShortcutsToLaunchPad`. Why stubs are not created is unknown; a
  skipped first-login prompt is the guess.

## Steps

1. Check Workspace is signed in and the desktop launches from Workspace itself.
   If not, this is not a shortcut problem.
2. Copy the template to `~/Applications/<Name>.app`.
3. Set the bundle ID and name:

   ```sh
   /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier <bundle id>' ~/Applications/<Name>.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c 'Set :CFBundleName <display name>' ~/Applications/<Name>.app/Contents/Info.plist
   ```

4. Write `Contents/Resources/Citralias.plist` per the table. Build `<B64>`:

   ```sh
   printf '%s' '<STORE_CODE>.<DESKTOP> $P<ID>' | base64 | tr '=' '-'
   ```

5. Re-sign and clear quarantine:

   ```sh
   codesign --force --deep -s - ~/Applications/<Name>.app
   xattr -cr ~/Applications/<Name>.app
   ```

6. Test: `open -b '<bundle id>'` (single-quote it, the `$` is literal).
7. Make the launcher as in README step 6.3.

If the stub opens but nothing launches, diff against a Workspace-made stub and
check the Workspace logs: Workspace may need to register the alias on its side.

## Fallback

Copy a working stub from another machine and run `xattr -cr` on it. It holds no
per-machine data. Also untested.
