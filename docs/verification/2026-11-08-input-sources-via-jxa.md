# Input sources: can they be enabled without a compiler?

- **Date:** 2026-11-08
- **Question:** can the enabled keyboard layouts be defined in the repo and applied on a new machine, without the Swift toolchain (not present out of the box)?
- **Machine / keyboard:** work-new (Mac17,9), macOS 26.7.2, arm64. No keyboard involved.

## Command

Two JXA scripts, run with `osascript -l JavaScript` (ships with macOS; uses
the system's `Carbon.bridgesupport`, no Command Line Tools needed).

`list.js` — enabled input source IDs:

```js
ObjC.import('Carbon');
const arr = ObjC.castRefToObject($.TISCreateInputSourceList(null, false));
const out = [];
for (let i = 0; i < arr.count; i++) out.push(ObjC.unwrap(ObjC.castRefToObject($.TISGetInputSourceProperty(arr.objectAtIndex(i), $.kTISPropertyInputSourceID))));
out.join(', ');
```

`tis3.js` — enable or disable one source by ID:

```js
ObjC.import('Carbon');
function run(argv) {
  const [action, id] = argv;
  const key = ObjC.castRefToObject($.kTISPropertyInputSourceID);
  const filter = $.NSDictionary.dictionaryWithObjectForKey($(id), key);
  const arr = ObjC.castRefToObject($.TISCreateInputSourceList(filter, true));
  if (Number(arr.count) !== 1) return 'not found: ' + id;
  const src = arr.objectAtIndex(0);
  const fn = action === 'enable' ? $.TISEnableInputSource : $.TISDisableInputSource;
  return action + ' ' + id + ' -> OSStatus ' + fn(src);
}
```

```sh
echo "before: $(osascript -l JavaScript list.js)"
osascript -l JavaScript tis3.js enable com.apple.keylayout.US
echo "after enable (TIS): $(osascript -l JavaScript list.js)"
sleep 2; echo "after enable (plist):"; defaults read com.apple.HIToolbox AppleEnabledInputSources | grep -i name
osascript -l JavaScript tis3.js disable com.apple.keylayout.US
echo "after disable (TIS): $(osascript -l JavaScript list.js)"
sleep 2; echo "after disable (plist):"; defaults read com.apple.HIToolbox AppleEnabledInputSources | grep -i name
```

## Output

```
before: com.apple.keylayout.SwissGerman, com.apple.CharacterPaletteIM
enable com.apple.keylayout.US -> OSStatus 0
after enable (TIS): com.apple.keylayout.SwissGerman, com.apple.CharacterPaletteIM, com.apple.keylayout.US
after enable (plist):
        "KeyboardLayout Name" = "Swiss German";
        "KeyboardLayout Name" = "U.S.";
disable com.apple.keylayout.US -> OSStatus 0
after disable (TIS): com.apple.keylayout.SwissGerman, com.apple.CharacterPaletteIM
after disable (plist):
        "KeyboardLayout Name" = "Swiss German";
```

The first attempt printed `not found` for both calls and changed nothing: JXA
bridges `NSArray.count` as a **string** (`"1"`), so `arr.count !== 1` was
always true. Wrap it in `Number()`.

## Conclusion

Input sources can be enabled and disabled from the base config with no
toolchain: JXA calls `TISEnableInputSource`/`TISDisableInputSource` directly,
the change is live immediately (no logout), and macOS persists it to
`com.apple.HIToolbox` itself. Swift is not needed for this; it stays confined
to the optional overlay module.

Not checked: `TISSelectInputSource`, Input-menu order when several sources are
enabled in sequence, and whether an MDM profile on this machine restricts
input sources (none interfered here).
