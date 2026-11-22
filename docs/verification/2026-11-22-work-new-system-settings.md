# work-new: system settings by `defaults`, and what blocks the rest

- **Date:** 2026-11-22
- **Question:** backlog › macOS defaults module, "To probe": what Modifier Keys and "Press 🌐 key to" write, so the README §3 steps can be scripted; and which of the kept defaults can be applied on work-new.
- **Machine / keyboard:** work-new (Mac17,9), macOS 26.7.2, built-in keyboard (ISO). Intune-managed.

## 1. Caps Lock → fn and "Press 🌐 key to" (set by hand, diffed)

Snapshots of `defaults -currentHost read -g`, `defaults read -g` and
`defaults read com.apple.HIToolbox` before and after setting both in System
Settings. The first attempt went to a remembered Logitech receiver (selected
in the pane's keyboard dropdown), the second to the internal keyboard:

```
=== currenthost-global
9a10,15
>     "com.apple.keyboard.modifiermapping.1133-50504-0" =     (
>                 {
>             HIDKeyboardModifierMappingDst = 1095216660483;
>             HIDKeyboardModifierMappingSrc = 30064771129;
>         }
>     );
=== hitoolbox
17a18
>     AppleFnUsageType = 0;
=== global
```

After setting it for the internal keyboard (and the receiver back to Caps Lock):

```
    "com.apple.keyboard.modifiermapping.0-0-0" =     (
                {
            HIDKeyboardModifierMappingDst = 1095216660483;
            HIDKeyboardModifierMappingSrc = 30064771129;
        }
    );
    "com.apple.keyboard.modifiermapping.1133-50504-0" =     (
                {
            HIDKeyboardModifierMappingDst = 30064771129;
            HIDKeyboardModifierMappingSrc = 30064771129;
        }
    );
```

`hidutil list`: the internal keyboard reports VendorID 0x0, ProductID 0x0
(`1133-50504` is Logitech `0x046D`/`0xC548`, a Bolt receiver).

- Caps → fn: `defaults -currentHost` global
  `com.apple.keyboard.modifiermapping.<vendor>-<product>-0`, array of one dict,
  Src `30064771129` (`0x700000039`, Caps Lock), Dst `1095216660483`
  (`0xFF00000003`, fn). Internal keyboard: `0-0-0`.
- "Press 🌐 key to" → Do Nothing: `com.apple.HIToolbox AppleFnUsageType = 0`.

Not checked: whether writing these with `defaults` (instead of Settings)
takes effect, and when (Settings applies them immediately).

## 2. Applied with `defaults`

Before → after, read back with `defaults read`:

| Setting | Before | After |
|---|---|---|
| `-g ApplePressAndHoldEnabled` | unset (picker on) | `0` |
| `-g KeyRepeat` | unset | `1` |
| `-g InitialKeyRepeat` | unset | `10` |
| `com.apple.AppleMultitouchTrackpad Clicking` | `0` | `1` |
| `com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking` | `0` | `1` |
| `-currentHost -g com.apple.mouse.tapBehavior` | unset | `1` |
| `com.apple.dock autohide` / `autohide-delay` | unset | `1` / `5` (then `killall Dock`) |
| `com.apple.symbolichotkeys` 60 (previous source) | enabled, `(32, 49, 262144)` ⌃Space | `enabled = 0; (65535, 65535, 0)` |
| `com.apple.symbolichotkeys` 61 (next source) | enabled, `(32, 49, 786432)` ⌃⌥Space | `enabled = 1; (32, 49, 1966080)` hyper+Space |

Key repeat and tap-to-click took effect after logout (tap-to-click needed it;
key repeat already worked before).

### Symbolic hotkeys: the values must be typed

The first write used the old-style string form:

```sh
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '{enabled = 1; value = {parameters = (32, 49, 1966080); type = standard;};}'
```

`defaults read` showed the expected values, but neither `activateSettings -u`
nor a logout changed anything: Settings still listed ⌃Space and
`caps+space` did nothing. `plutil -p` showed why — everything was stored as
strings, unlike the entries macOS writes itself:

```
    "60" => {
      "enabled" => "0"
      "value" => {
        "parameters" => [
          0 => "65535"
          1 => "65535"
          2 => "0"
        ]
        "type" => "standard"
      }
    }
    "61" => {
      "enabled" => "1"
      "value" => {
        "parameters" => [
          0 => "32"
          1 => "49"
          2 => "1966080"
        ]
        "type" => "standard"
      }
    }
    ...
    "164" => {
      "enabled" => false
      "value" => {
        "parameters" => [
          0 => 65535
          1 => 65535
          2 => 0
        ]
        "type" => "standard"
      }
    }
```

Rewritten with XML values, then reloaded:

```sh
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1966080</integer></array><key>type</key><string>standard</string></dict></dict>'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>65535</integer><integer>0</integer></array><key>type</key><string>standard</string></dict></dict>'
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
```

```
    "60" => {
      "enabled" => false
      "value" => {
        "parameters" => [
          0 => 65535
          1 => 65535
          2 => 0
        ]
        "type" => "standard"
      }
    }
    "61" => {
      "enabled" => true
      "value" => {
        "parameters" => [
          0 => 32
          1 => 49
          2 => 1966080
        ]
        "type" => "standard"
      }
    }
```

`caps+space` switched layouts in Notes straight away, no logout.

## 3. Reduce Motion cannot be written

```
$ defaults read com.apple.universalaccess reduceMotion
The domain/default pair of (com.apple.universalaccess, reduceMotion) does not exist
$ defaults write com.apple.universalaccess reduceMotion -bool true
2026-11-22 17:45:12.880 defaults[7454:4157842] Could not write domain com.apple.universalaccess; exiting
```

Reading works, writing is refused. Manual step (Accessibility → Display), or
a script that checks and opens the pane.

## 4. Terminal.app hides keystrokes from Hammerspoon (managed)

`caps+hjkl` worked in Notes but not in Terminal. Hammerspoon had been loaded
since 2026-11-08 and was reloaded (`open -g hammerspoon://reload`) first; no
change for Terminal.

```
$ ioreg -l -w 0 | grep -o '"kCGSSessionSecureInputPID"=[0-9]*' | sort -u
"kCGSSessionSecureInputPID"=26263
26263 /System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
$ defaults read com.apple.Terminal SecureKeyboardEntry
0
```

Terminal → Secure Keyboard Entry is ticked and cannot be unticked:

```
/Library/Managed Preferences/com.apple.Terminal.plist
{
  "PayloadUUID" => "2CA75CEA-FA71-4C25-876D-BC8E251B542F"
  "SecureKeyboardEntry" => true
}
/Library/Managed Preferences/patrice.damian.marti/com.apple.Terminal.plist
{
  "PayloadUUID" => "2CA75CEA-FA71-4C25-876D-BC8E251B542F"
  "SecureKeyboardEntry" => true
}
```

No other terminal app appears in `/Library/Managed Preferences/`.

## Conclusion

- README §3 steps 1 and 2 are scriptable in principle: the values are known.
  Whether a `defaults` write alone takes effect is still open.
- README §3 step 3 is scriptable and verified: `defaults` with **typed XML
  values** + `activateSettings -u`, no logout. The `{enabled = 1; …}` string
  form is silently ignored.
- On work-new, **Intune forces Secure Keyboard Entry in Terminal.app**, so no
  event tap sees keys while Terminal is frontmost: no fn layer, no window
  cycling there. Not fixable from the user side; use another terminal (if one
  can be installed) or an IDE's built-in terminal.
- Reduce Motion stays manual.
