# Citrix desktop stub built by hand on work-new

- **Date:** 2026-11-22
- **Question:** does `docs/citrix-stub-by-hand.md` (then untested) give a working Spotlight launcher for the BJB desktop on a machine where Workspace creates no stub?
- **Machine / keyboard:** work-new (Mac17,9), macOS 26.7.2, Citrix Workspace 26.09.0.17. Keyboard not relevant.

## Why Workspace creates no stub here

Apps cache (`~/Library/Application Support/Citrix Receiver/Apps Cache https_citrixstore_juliusbaer_comcitrixch150discovery.ctx`), start of the file:

```
<resources xmlns="http://citrix.com/delivery-services/2-0/resources" xmlns:a="http://citrix.com/delivery-services/2-0/subscriptions" enumeration="full" a:subscriptionsstatus="disabled"><resource><id>Cloud-CH150.RPCA-UC3 - PRD $P22062</id>...<resourcetype>Citrix.MPS.Desktop</resourcetype>...<launchica><url>https://citrixstore.juliusbaer.com/Citrix/CH150/resources/v2/Q2xvdWQtQ0gxNTAuUlBDQS1VQzMgLSBQUkQgJFAyMjA2Mg--/launch/ica</url></launchica>
```

Workspace log:

```
DZStoreConnection.m | 3990 | -[DZStoreConnection refreshSettingValueToAddShortcutsToLaunchPad] | LM_Store | LL_ALWAYS | isSkipCreatingFavouriteAppsOnDiskEnabled Flag enabled. shouldAddShortcutsToLaunchPad = 1,
```

No star/favourite option in the Workspace UI.

## Attempt 1: stub in `~/Applications`, per the draft

Built from `Templates/DockApplication.app`, values from the apps cache and
`ServiceRecords.plist`; `printf '%s' 'Cloud-CH150.RPCA-UC3 - PRD $P22062' | base64 | tr '=' '-'`
gave `Q2xvdWQtQ0gxNTAuUlBDQS1VQzMgLSBQUkQgJFAyMjA2Mg--`, identical to the
cache's launch URL. Re-signed ad hoc; `spctl -a -vv` → `rejected`.

Removed by Workspace within seconds:

```
 20:43:25.124  | -[MacInstalledAppsController updateInstalledAppPaths]  | UpdateSubscriptionArray as newSubscriptionPaths is different to installedAppsPaths
 20:43:25.125  | -[ICAFileSubscriptionManager removeSubscriptionAtPath:error:]  | Remove subscription at path: /Users/patrice.damian.marti/Applications/RPCA-UC3 - PRD.app
```

Not in the Trash; `mdatp threat list` → `No threats.`

## Attempt 2: stub in `~/Library/Application Support/CitrixStubs/`

Still present after 60 s, no removal in the log. Launcher
`~/Applications/BJB Citrix Desktop.app` opens it by path.

- With `Store Name` = `citrixstore.juliusbaer.com` (as on work-old): dialog
  "App not available — Try adding the application again, or contact your help
  desk with this information: Store "citrixstore.juliusbaer.com" no longer
  exists." Workspace knows the store as `CH150`
  (`com.citrix.ReceiverFTU.AccountRecords`: `name = CH150`;
  `ServiceRecords.plist`: `"Name" => "CH150"`).
- With `Store Name` = `CH150`: the launch went through to the host, then the
  server terminated it (the user had just disconnected the session):

  ```
   21:28:18.697  |    getDataPoint  | ... Message: Connected successfully via CGP TCP., Code: Transport.Connect.Success
   21:28:18.853  |    getDataPoint  | ... Message: Engine connected successfully., Code: Session.Connect.Success
   21:28:20.159  |    IcaTerminate  | Received PACKET_TERMINATE: Command=1
   21:28:20.178  |    getDataPoint  | ... Message: Error_SERVER_CONNECTION_BROKEN_HOST, Code: Session.Launch.Failed
  ```

  Shortly after, launching from Workspace worked, and so did the Spotlight
  launcher (user, same evening): transient.

## Conclusion

The hand-built stub works with three changes to the draft, now in
`docs/citrix-stub-by-hand.md`: keep it outside `~/Applications`, set
`Store Name` to the store's name in Workspace, and have the launcher open it by
path. Not checked: whether it survives a Workspace update (the template and its
frameworks are copied, so an update does not refresh them).
