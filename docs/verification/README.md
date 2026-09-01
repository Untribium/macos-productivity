# Verification log

Output from probes that had to be run on the Mac, because a Cowork session
cannot reach macOS itself (SETUP.md §0).

**One file per probe.** Name: `YYYY-MM-DD-short-slug.md`.

Template:

```markdown
# <what was being established>

- **Date:** YYYY-MM-DD
- **Question:** the §7 open question this answers, quoted
- **Machine / keyboard:** built-in | Zeal60 | both, macOS version

## Command

​```sh
<exactly what was run>
​```

## Output

​```
<pasted verbatim, untrimmed>
​```

## Conclusion

What this settles, and the SETUP.md edit it implies (§ number).
Leave the question open explicitly if it does not settle it.
```

Rules:

- Paste output verbatim. A trimmed plist is how the input-source trap in §7 hid
  for as long as it did.
- A probe that fails or is inconclusive still gets a file. Knowing something was
  tried and did not work is the point.
- Filing a probe does not close an open question — that needs the §7 and §8 edit.

## Pending probes

| Probe | Question | §  |
|---|---|---|
| Auto-reload through the symlink | does a repo-side edit trigger `hs.reload()`, and does the notification name the repo path? | §7 |
| Input Monitoring | does the fn tap need it in addition to Accessibility? | §3, §7 |
| `hs.spaces` on 26.6.2 | does it work reliably enough to own layer 3? | §7 |
| Zeal60 VIA fn audit | is its fn a plain `MO()`, and does it send a real fn keycode? | §7 |
