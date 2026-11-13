# Verification log

Output from probes run on a Mac: things a session could not see directly, or
that needed a person at the keyboard. Kept so the next session does not re-ask.

Files before 2026-11-08 cite the old `SETUP.md` by section number: §3–§5 are
now `docs/keymap.md`; §7 (open questions), §8 (decision log) and the rest are in
`hammerspoon/DESIGN.md`.

**One file per probe.** Name: `YYYY-MM-DD-short-slug.md`.

Template:

```markdown
# <what was being established>

- **Date:** YYYY-MM-DD
- **Question:** the open question this answers, quoted (from the component's `DESIGN.md`)
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

What this settles, and the `DESIGN.md` or `docs/keymap.md` edit it implies.
Leave the question open explicitly if it does not settle it.
```

Rules:

- Paste output verbatim. A trimmed plist is how the input-source trap (`hammerspoon/DESIGN.md`) hid
  for as long as it did.
- A probe that fails or is inconclusive still gets a file. Knowing something was
  tried and did not work is the point.
- Filing a probe does not close an open question — that needs the edit to Open questions and the Decision log.

## Pending probes

| Probe | Question | Doc |
|---|---|---|
| Input Monitoring | does the fn tap need it in addition to Accessibility? | `hammerspoon/DESIGN.md` |
| `hs.spaces` on 26.6.2 | does it work reliably enough to own layer 3? | `hammerspoon/DESIGN.md` |
| Dotfiles on work-new | what is its live vim and zsh config? (same command as `2026-11-13-dotfiles-work-old.md`) | `docs/backlog.md` |
| Zeal60 VIA fn audit | is its fn a plain `MO()`, and does it send a real fn keycode? | `hammerspoon/DESIGN.md` |
