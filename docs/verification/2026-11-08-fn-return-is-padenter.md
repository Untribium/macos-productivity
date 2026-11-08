# fn+Return arrives at the fn layer as keypad Enter

- **Date:** 2026-11-08
- **Question:** why does `caps+Return` not toggle the overlay, when a synthetic hyper+Return does?
- **Machine / keyboard:** flurry (Mac14,9), built-in keyboard, macOS 27.0.1

## Command

A listen-only `hs.eventtap` on keyDown, run as `hammerspoon/probes/active.lua`
for 60 s, logging keycode, key name and modifiers. Pressed `caps+Return`
several times, then plain Return.

## Output

```
2026-11-08T12:55:53 I probe: keyDown 76 (padenter) mods={fn}
2026-11-08T12:55:55 I probe: keyDown 76 (padenter) mods={fn}
2026-11-08T12:55:55 I probe: keyDown 76 (padenter) mods={fn}
2026-11-08T12:55:55 I probe: keyDown 76 (padenter) mods={fn}
2026-11-08T12:55:56 I probe: keyDown 76 (padenter) mods={fn}
2026-11-08T12:55:58 I probe: keyDown 36 (return) mods={}
2026-11-08T12:55:58 I probe: keyDown 36 (return) mods={}
```

(Later lines were unrelated typing and are left out.)

## Conclusion

macOS turns fn+Return into keypad Enter (keycode 76) before the session event
tap sees it, so a fn-layer binding on `return` (36) never matches. Bound on
`padenter` instead (`keymap.lua`, SETUP.md §5). The app side was fine: a
synthetic hyper+Return from Hammerspoon reached the Carbon hotkey.

Not checked: the Zeal60. Its caps is remapped to fn by macOS too, so the same
translation is expected, but unverified.
