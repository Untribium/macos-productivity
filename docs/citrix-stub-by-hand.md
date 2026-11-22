# Citrix desktop stub, built by hand

For a machine where Citrix Workspace does **not** create the per-desktop app in
`~/Applications` (README step 6.1). **Tested on work-new 2026-11-22: works**,
with three corrections to the first draft (marked below): the stub must live
outside `~/Applications`, `Store Name` is the store's name in Workspace, not
its host, and the launcher opens the stub by path.

Placeholders: `<STORE_HOST>` store hostname, `<STORE_PATH>` store path on that
host (the part before `/discovery`), `<GATEWAY_URL>` external gateway,
`<STORE_CODE>` the store's code in the unique name, `<STORE_NAME>` the store's
name in Workspace, `<DESKTOP>` published desktop name, `<ID>` the `$P<number>`
suffix. The concrete values for the work setup are in the README.

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
  | `Store Name` | **`<STORE_NAME>`** — see below |
  | `cloneName` | `<DESKTOP>.app` |

- `<B64>` is the unique application name, base64, with `=` padding written as
  `-`. Seen with `+`/`/`-free input only, so the URL-safe mapping of those two
  is unconfirmed. Check it against Workspace's own cache:
  `~/Library/Application Support/Citrix Receiver/Apps Cache *.ctx` has every
  resource's `<id>` and `launchica` URL.
- The `$P<ID>` is assigned by the store per published resource. Several stubs
  can share a display name with different IDs, so take it from the apps cache
  above or a Workspace-made stub; do not guess.
- **`Store Name` must match the store's name in Workspace** (correction).
  On work-old it was the host (`<STORE_HOST>`); on work-new the account was
  set up differently and the store is called `CH150`
  (`defaults read com.citrix.ReceiverFTU.AccountRecords` → `name`). With the
  host there, the stub showed "App not available … Store "<STORE_HOST>" no
  longer exists".
- **Workspace deletes stubs in `~/Applications`** (correction). It syncs that
  folder with the store's subscriptions; with subscriptions disabled on the
  store (`subscriptionsstatus="disabled"` in the apps cache), a hand-built stub
  there was removed within seconds (Workspace log:
  `-[ICAFileSubscriptionManager removeSubscriptionAtPath:error:] Remove
  subscription at path: …`). Elsewhere it is left alone and still launches.
- Why Workspace creates no stubs itself: its log says
  `isSkipCreatingFavouriteAppsOnDiskEnabled Flag enabled`, a Citrix feature
  flag. Only the store's admins can change that.

## Steps

1. Check Workspace is signed in and the desktop launches from Workspace itself.
   If not, this is not a shortcut problem.
2. Copy the template **outside `~/Applications`**, e.g.
   `~/Library/Application Support/CitrixStubs/<Name>.app` (`ditto`).
3. Set the bundle ID and name:

   ```sh
   /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier <bundle id>' "<stub>/Contents/Info.plist"
   /usr/libexec/PlistBuddy -c 'Set :CFBundleName <display name>' "<stub>/Contents/Info.plist"
   ```

4. Write `Contents/Resources/Citralias.plist` per the table (`plistlib` keeps
   the types right). Build `<B64>`:

   ```sh
   printf '%s' '<STORE_CODE>.<DESKTOP> $P<ID>' | base64 | tr '=' '-'
   ```

5. Re-sign and clear quarantine (`spctl` then reports "rejected"; it still
   runs, as nothing quarantined it):

   ```sh
   codesign --force --deep -s - "<stub>"
   xattr -cr "<stub>"
   ```

6. Make the launcher in `~/Applications`, opening the stub **by path**
   (correction: the stub is not in a folder LaunchServices indexes, so
   `open -b` does not find it):

   ```sh
   osacompile -o ~/Applications/"<Launcher Name>.app" -e \
     'do shell script "open \"$HOME/Library/Application Support/CitrixStubs/<Name>.app\""'
   ```

   No symlink to the stub in `~/Applications`: Workspace would find it there.

7. Test from Spotlight. If the session fails with "Connection was terminated
   by the server" right after you disconnected one, wait a minute: on work-new
   that was transient (the log showed the transport connected, then
   `PACKET_TERMINATE` from the host).
