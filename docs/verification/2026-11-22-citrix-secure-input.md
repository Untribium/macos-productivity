# Citrix Viewer: why the Hammerspoon config does nothing in a session

- **Date:** 2026-11-22
- **Question:** the fn layer (`caps+hjkl`, caps-tap → Escape) does nothing in a Citrix session, as on work-old — secure input, or a setting?
- **Machine / keyboard:** work-new (Mac17,9), macOS 26.7.2, built-in keyboard. Citrix Workspace 26.09.0.17.

## Symptom

In a Citrix session, `caps+h` triggers macOS's own 🌐+H animation (the same
as in Terminal, which is in secure input), and a lone caps tap does nothing.
So Hammerspoon never sees the keys.

## Command 1: secure input PID while switching apps

```sh
for i in $(seq 1 25); do
  front=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | sed 's/.*="\(.*\)"/\1/')
  sec=$(ioreg -l -w 0 | grep -o '"kCGSSessionSecureInputPID"=[0-9]*' | head -1 | cut -d= -f2)
  secname=$([ -n "$sec" ] && ps -o comm= -p "$sec" 2>/dev/null | sed 's#.*/##')
  printf '%2ds  front=%-28s secureInput=%s\n' "$i" "$front" "${sec:-none} ${secname}"
  sleep 1
done
```

```
 1s  front=Terminal                     secureInput=23168 Terminal
 2s  front=Terminal                     secureInput=23168 Terminal
 3s  front=Citrix Viewer                secureInput=23168 Terminal
 4s  front=Citrix Viewer                secureInput=23168 Terminal
 5s  front=Citrix Viewer                secureInput=23168 Terminal
 6s  front=Citrix Viewer                secureInput=23168 Terminal
 7s  front=Citrix Viewer                secureInput=23168 Terminal
 8s  front=Citrix Viewer                secureInput=23168 Terminal
 9s  front=Citrix Viewer                secureInput=23168 Terminal
10s  front=Citrix Viewer                secureInput=23168 Terminal
11s  front=Citrix Viewer                secureInput=23168 Terminal
12s  front=Citrix Viewer                secureInput=23168 Terminal
13s  front=Citrix Viewer                secureInput=23168 Terminal
14s  front=Citrix Viewer                secureInput=23168 Terminal
15s  front=Citrix Viewer                secureInput=23168 Terminal
16s  front=Citrix Viewer                secureInput=23168 Terminal
17s  front=Citrix Viewer                secureInput=23168 Terminal
18s  front=Citrix Viewer                secureInput=23168 Terminal
19s  front=Citrix Viewer                secureInput=23168 Terminal
20s  front=Citrix Viewer                secureInput=23168 Terminal
21s  front=Citrix Viewer                secureInput=23168 Terminal
22s  front=Citrix Viewer                secureInput=23168 Terminal
23s  front=Citrix Viewer                secureInput=23168 Terminal
24s  front=Citrix Viewer                secureInput=23168 Terminal
25s  front=Citrix Viewer                secureInput=23168 Terminal
```

Misleading on its own: it looked as if Citrix did not take secure input.
Command 3 shows the PID lags behind app switches.

## Command 2: event taps (one-off Swift tool, `CGGetEventTapList`)

```
pid  17365  DgSessionSvc point=session FILTER on  keys=yes
pid  17461  Hammerspoon point=session FILTER on  keys=yes
pid  17339  NotificationCenter point=session listen on  keys=no
pid  17340  ViewBridgeAuxiliary point=session listen on  keys=yes
pid  17243  universalaccessd point=session listen off keys=yes
pid  17243  universalaccessd point=session listen off keys=no
pid  17243  universalaccessd point=session listen on  keys=no
```

No Citrix tap. `DgSessionSvc` is Digital Guardian (DLP); it filters keys but
the config works in Notes, so it is not the blocker.

## Command 3: `IsSecureEventInputEnabled()` while switching apps

```sh
for i in $(seq 1 30); do
  front=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | sed 's/.*="\(.*\)"/\1/')
  on=$(osascript -l JavaScript -e 'ObjC.import("Carbon"); $.IsSecureEventInputEnabled()' 2>/dev/null)
  sec=$(ioreg -l -w 0 | grep -o '"kCGSSessionSecureInputPID"=[0-9]*' | head -1 | cut -d= -f2)
  printf '%2ds  front=%-22s secureInputActive=%-5s pid=%s\n' "$i" "$front" "$on" "${sec:-none}"
  sleep 1
done
```

```
 1s  front=Terminal               secureInputActive=true  pid=23168
 2s  front=Terminal               secureInputActive=true  pid=23168
 3s  front=Citrix Viewer          secureInputActive=true  pid=23168
 4s  front=Citrix Viewer          secureInputActive=true  pid=23168
 5s  front=Citrix Viewer          secureInputActive=true  pid=23168
 6s  front=Citrix Viewer          secureInputActive=true  pid=23168
 7s  front=Notes                  secureInputActive=false pid=none
 8s  front=Notes                  secureInputActive=false pid=none
 9s  front=Notes                  secureInputActive=false pid=none
10s  front=Google Chrome          secureInputActive=false pid=none
11s  front=Google Chrome          secureInputActive=false pid=none
12s  front=Google Chrome          secureInputActive=false pid=none
13s  front=Google Chrome          secureInputActive=false pid=none
14s  front=Google Chrome          secureInputActive=false pid=none
15s  front=Google Chrome          secureInputActive=false pid=none
16s  front=Google Chrome          secureInputActive=false pid=none
17s  front=Google Chrome          secureInputActive=false pid=none
18s  front=Google Chrome          secureInputActive=false pid=none
19s  front=Citrix Viewer          secureInputActive=true  pid=24256
20s  front=Citrix Viewer          secureInputActive=true  pid=24256
21s  front=Citrix Viewer          secureInputActive=true  pid=24256
22s  front=Citrix Viewer          secureInputActive=true  pid=24256
23s  front=Citrix Viewer          secureInputActive=true  pid=24256
24s  front=Citrix Viewer          secureInputActive=true  pid=24256
25s  front=Citrix Viewer          secureInputActive=true  pid=24256
26s  front=Citrix Viewer          secureInputActive=true  pid=24256
27s  front=Citrix Viewer          secureInputActive=true  pid=24256
28s  front=Citrix Viewer          secureInputActive=true  pid=24256
29s  front=Citrix Viewer          secureInputActive=true  pid=24256
30s  front=Citrix Viewer          secureInputActive=true  pid=24256
```

```
$ ps -o pid=,comm= -p 24256
24256 /Applications/Citrix Workspace.app/Contents/Frameworks/CitrixWorkspaceApps.framework/Versions/26.09.0.17/Helpers/CitrixWorkspaceApps/Citrix Viewer.app/Contents/MacOS/Citrix Viewer
```

No Citrix entry in `/Library/Managed Preferences/`, and none in the managed
TCC profile (`com.apple.TCC.configuration-profile-policy.plist`).

## Conclusion

- **Citrix Viewer enables secure input itself** while it is frontmost; it is
  off again in other apps. Not managed by Intune. Event taps, Hammerspoon's
  included, see no keys in a session — by design, not a setting we found.
- Not checked: whether a Citrix Workspace preference turns it off.
- Measuring secure input: `IsSecureEventInputEnabled()` is reliable;
  `kCGSSessionSecureInputPID` names the owner but can stay on the previous
  app for several seconds after a switch.
- Idea, not planned: Hammerspoon's app watcher (no key events needed) swaps
  caps to another key with `hidutil`, which works below secure input, while
  Citrix is active, and a script in the remote Windows (e.g. AutoHotkey)
  builds the nav layer from it. Depends on being allowed to run such a
  script there.
