# shell-snapshot

Raw copies of the live zsh config, one folder per machine, taken so it can be
read from another machine. Input for the shell spike (`docs/backlog.md` ›
Shell). Not loaded by anything; this branch is not meant to be merged as is.

## work-old (2026-11-18)

Copied with `cp -L`, so symlinks are resolved to their contents.

| File here | Lives at | Notes |
|---|---|---|
| `.zshenv` | `~/.zshenv` | sets `ZDOTDIR=~/.zsh` |
| `.zprofile` | `~/.zsh/.zprofile` | |
| `.zshrc.local` | `~/.zsh/.zshrc.local` | symlink to old `~/Data/tools/setup/shell/resources/zshrc.local` |
| `plugins/autocompletions` | `~/.zsh/plugins/` | symlink to the old tree |
| `plugins/bjb-channels-repo-config` | `~/.zsh/plugins/` | local only |
| `plugins/claude-profiles` | `~/.zsh/plugins/` | local only |

Not copied: `~/.zsh/.zshrc`, the stock grml zshrc
(<https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc>), 130 KB, unmodified as
far as known; history, caches and `.zcompdump*`.
