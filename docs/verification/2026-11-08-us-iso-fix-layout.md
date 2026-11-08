# US (ISO-safe): a custom layout that swaps `§`/`` ` `` on ISO keyboards only

- **Date:** 2026-11-08
- **Question:** "Why work has two US layouts" (§7) — can one custom US layout fix `` ` ``/`~` on the ISO work machines without breaking ANSI keyboards, and can bootstrap install it?
- **Machine / keyboard:** work-new (Mac17,9), built-in keyboard (ISO, keyboard type 92), macOS 26.7.2. Zeal60 not tested.

## Starting point

`US ISO HiTilde.keylayout` (Ukelele 3.2.7, 2019; branch `machine-setup`) swaps
keycodes 10 and 50 in its **default** key map set, in the plain and shift maps
only. Every keyboard type uses that set except JIS, so on an ANSI keyboard the
key left of `1` (keycode 50) would type `§`/`±` and `` ` ``/`~` would be
unreachable.

## Command

1. Which keyboard types macOS calls ISO (JXA, `KBGetLayoutType` over 0–255):

   ```
   ANSI (69): 1,2,3,6,8,12,16,24,27,28,31,34,37,40,43,46,49,52,55,58,61,64,67,70,73,76,79,82,85,88,91,94,97,100,103,106,109,112,115,118,121,124,127,130,133,136,139,142,145,148,151,154,157,160,163,166,169,172,175,178,181,184,187,190,193,195,198,202,204
   ISO (67): 4,5,7,9,13,17,20,25,29,32,35,38,41,44,47,50,53,56,59,62,65,68,71,74,77,80,83,86,89,92,95,98,101,104,107,110,113,116,119,122,125,128,131,134,137,140,143,146,149,152,155,158,161,164,167,170,173,176,179,182,185,188,191,196,199,203,205
   JIS (66): 18,21,22,23,26,30,33,36,39,42,45,48,51,54,57,60,63,66,69,72,75,78,81,84,87,90,93,96,99,102,105,108,111,114,117,120,123,126,129,132,135,138,141,144,147,150,153,156,159,162,165,168,171,174,177,180,183,186,189,192,194,197,200,201,206,207
   other (54): 0,10,11,14,15,19,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
   ```

   `LMGetKbdType()` on this machine: `92` → ISO.

2. A generator (Python, authoring-time only) rewrote HiTilde: default set back
   to stock US for 10/50; new `iso` key map set overriding 10↔50 in all eight
   modifier maps; every type 0–255 assigned explicitly (ISO → `iso`, the file's
   original JIS types → `984`, rest → default). Name `US ISO-fix`, id `-28417`.

3. Copied to `~/Library/Keyboard Layouts/`, then `TISRegisterInputSource` (JXA):

   ```
   register OSStatus 0; found: org.unknown.keylayout.USISO-fix
   ```

4. `UCKeyTranslate` on keycodes 10 and 50, plain and shift, for type 92 (ISO)
   and 40 (ANSI) — one-off Swift tool:

   ```
   US ISO  (92, this built-in): kc10=§  kc10+shift=±  kc50=`  kc50+shift=~
   US ANSI (40): kc10=§  kc10+shift=±  kc50=`  kc50+shift=~
   USISO-fix ISO  (92, this built-in): kc10=`  kc10+shift=~  kc50=§  kc50+shift=±
   USISO-fix ANSI (40): kc10=§  kc10+shift=±  kc50=`  kc50+shift=~
   ```

5. `TISEnableInputSource` (JXA) on the new layout:

   ```
   register 0
   before: EnableCapable=true Enabled=false SelectCapable=true
   enable 0
   after:  EnableCapable=true Enabled=false SelectCapable=true
   ```

   macOS then showed a **consent dialog** asking whether osascript may enable a
   keyboard layout. After clicking allow, the layout was enabled and selectable
   (not selected). Typing on the built-in keyboard: key left of `1` gives
   `` ` ``/`~` — confirmed by hand.

6. Stock US disabled again:

   ```
   before: com.apple.keylayout.SwissGerman, com.apple.CharacterPaletteIM, com.apple.keylayout.US, org.unknown.keylayout.USISO-fix
   disable com.apple.keylayout.US -> OSStatus 0
   after: com.apple.keylayout.SwissGerman, com.apple.CharacterPaletteIM, org.unknown.keylayout.USISO-fix
   ```

## Conclusion

- One layout file is safe for every machine: the swap applies to ISO keyboard
  types only; on ANSI it translates exactly like stock US. The work machines no
  longer need two US layouts (§7 open question).
- No logout needed: install → `TISRegisterInputSource` → `TISEnableInputSource`.
- **Enabling a third-party layout needs user consent.** The call returns 0
  immediately, and the source stays disabled until the dialog is accepted.
  Bootstrap must say so and re-check afterwards, not trust the return code.

Not checked: the Zeal60 (ANSI expected, type not read), a physical ANSI
keyboard on this layout, and whether the consent dialog appears again after a
reboot or on the next bootstrap run.

## Follow-up, same day: name, icon, and enabling after the first one

Renamed to **US (ISO-safe)** (file `US (ISO-safe).keylayout`, source ID
`org.unknown.keylayout.USISO-safe` — macOS strips spaces and brackets).

| Attempt | Result |
|---|---|
| `US ISO-fix.keylayout`, first enable in the session | consent dialog; allowed → enabled |
| `USISO.bundle` (icon + `TISIconIsTemplate`, display name in `InfoPlist.strings`) | `TISEnableInputSource` returns 0 and **launches System Settings** (Keyboard); nothing there to approve; not in Settings' `+` list. macOS also ignored `TISInputSourceID` in `Info.plist` and used `<CFBundleIdentifier>.keylayout.USISO` |
| `US (ISO-safe).keylayout`, same session, Settings quit first | same: Settings launches, nothing to approve |
| `US (ISO-safe).keylayout`, **after logout/login** | Settings launches **with** the consent prompt; allowed → enabled |

Settings builds its list of installed layouts at login, and Settings' own
list still showed the deleted `US ISO-fix` until then. Only the first
request in the session got the standalone dialog. So: a layout installed in
the current session can be enabled only once (the first dialog); after that,
enabling needs a fresh login.

Icon: a `US (ISO-safe).icns` next to the plain file **is** picked up, but a
plain file cannot mark it as a template, so it renders black in the Input
menu and the menu bar instead of adapting like Apple's badges. Dropped; the
layout uses the generic keyboard icon. Separately, Apple's own badges are not
fixed: Swiss German showed **A** while it was the only Latin layout and
**CH** once US was enabled too.

For bootstrap: install the file, call enable, then **re-check** enabled state.
If still off, tell the user to log out, log in and re-run; the enable then
goes through Settings' consent prompt.

## Follow-up 2: off→on, and where "enabled" is actually stored

With US (ISO-safe) enabled after login, disable then enable (JXA):

```
disable org.unknown.keylayout.USISO-safe -> OSStatus 0
after disable: com.apple.keylayout.SwissGerman, com.apple.CharacterPaletteIM, org.unknown.keylayout.USISO-safe
enable org.unknown.keylayout.USISO-safe -> OSStatus 0
after enable: com.apple.keylayout.SwissGerman, com.apple.CharacterPaletteIM, org.unknown.keylayout.USISO-safe
```

- Settings' consent prompt appeared again and came to the front on its own
  (Settings already running). **Approval is not remembered** across off→on.
- After approving, the Input menu showed only Swiss German, while the TIS list
  (`TISCreateInputSourceList(nil, false)`) still said enabled — as it had right
  after the disable. Re-added by hand in Settings (`+`), which worked.
- **The TIS enabled list is not trustworthy** after a disable/enable in the
  same session.

After logout/login, `defaults read com.apple.HIToolbox`:

```
{
    AppleCurrentKeyboardLayoutInputSourceID = "org.unknown.keylayout.USISO-safe";
    AppleEnabledInputSources =     (
                {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = 19;
            "KeyboardLayout Name" = "Swiss German";
        },
                {
            "Bundle ID" = "com.apple.CharacterPaletteIM";
            InputSourceKind = "Non Keyboard Input Method";
        }
    );
    AppleInputSourceHistory =     (
                {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = "-28417";
            "KeyboardLayout Name" = "US (ISO-safe)";
        },
                {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = 19;
            "KeyboardLayout Name" = "Swiss German";
        }
    );
    AppleInputSourceUpdateTime = "2026-11-08 13:10:50 +0000";
    AppleSavedCurrentInputSource =     {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = "-28417";
        "KeyboardLayout Name" = "US (ISO-safe)";
    };
    AppleSelectedInputSources =     (
                {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = "-28417";
            "KeyboardLayout Name" = "US (ISO-safe)";
        }
    );
}
```

`defaults read com.apple.inputsources`:

```
{
    AppleEnabledThirdPartyInputSources =     (
                {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = "-28417";
            "KeyboardLayout Name" = "US (ISO-safe)";
        }
    );
}
```

**Third-party layouts are stored apart from Apple's:** enabled custom layouts
live in `com.apple.inputsources` → `AppleEnabledThirdPartyInputSources`, never
in `com.apple.HIToolbox` → `AppleEnabledInputSources`. The "is it enabled?"
check must read both domains, match the custom layout by `KeyboardLayout ID`
(`-28417`), and not use the TIS list. Bootstrap must also skip the enable call
when the layout is already enabled, or every run prompts again.

The custom icon was still shown after removing the `.icns` until logout; after
login the generic keyboard icon is back.
