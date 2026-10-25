# Auto-reload through the symlink, and which directory is watched

- **Date:** 2026-10-25
- **Question:** "Does auto-reload survive the symlink?" and "Does
  `debug.getinfo(1,"S").source` give an absolute path here?" (§7, repo/workflow)
- **Machine / keyboard:** n/a (no keypresses involved). Hammerspoon 1.1.1

Run by Claude Code running natively on the Mac (not a Cowork VM), right after
`bootstrap.sh --apply` and a Hammerspoon relaunch.

## Command

Repo-side edits only: `hammerspoon/modules/urlctl.lua` created, then
`hammerspoon/modules/fnlayer.lua` and `hammerspoon/init.lua` edited, all through
the repo path. Nothing in `~/.hammerspoon` was touched. Then:

```sh
cat .live-status.json
open -g "hammerspoon://status";  sleep 1.5; grep -E '"(reason|loaded|written)"' .live-status.json
open -g "hammerspoon://reload";  sleep 3;   grep -E '"(reason|loaded)"' .live-status.json
```

## Output

```
{
  "reason" : "load",
  "loaded" : "2026-10-25T15:07:21",
  "accessibility" : true,
  "configdir" : "\/Users\/gray\/.hammerspoon",
  "fnBindings" : [
    "h",
    "j",
    "k",
    "l",
    "space"
  ],
  "watching" : "\/Users\/gray\/Projects\/claude\/macos-productivity\/hammerspoon",
  "fnTap" : true,
  "written" : "2026-10-25T15:07:21",
  "hsVersion" : "1.1.1"
}
```

```
  "reason" : "requested",
  "loaded" : "2026-10-25T15:07:21",
  "written" : "2026-10-25T15:07:32",
---
  "reason" : "load",
  "loaded" : "2026-10-25T15:07:34",
```

## Conclusion

- **Auto-reload survives the symlink.** `.live-status.json` is only written by
  `urlctl.lua`, which existed only after the repo-side edits. The file appeared
  without a manual reload, so a repo-side write triggered `hs.reload()`.
  Closes the §7 question.
- **`configRoot()` resolves the link.** `watching` is the repo path, not
  `hs.configdir`, so `debug.getinfo` returns an absolute path and the fallback
  did not fire. Closes the §7 question.
- `hammerspoon://status` rewrites without reloading (`loaded` unchanged), and
  `hammerspoon://reload` reloads (`loaded` advanced). Both endpoints work.
- **Not established here:** that the keys behave. `fnTap: true` and the
  binding list show the tap is running with the expected specs. Whether
  caps+hjkl, lone-tap Escape and caps+space work still needs a person at the
  keyboard (§10 re-verify note stays open until then).
