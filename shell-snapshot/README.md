# shell-snapshot

Raw copies of the live shell, git and editor config, one folder per machine,
taken so it can be read from another machine. Input for the shell spike (`docs/backlog.md` ›
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
| `git/gitconfig` | `~/.gitconfig` | `[user] email` redacted |
| `git/ignore` | `~/.config/git/ignore` | global gitignore |
| `vim/vimrc`, `vim/vimrc.local` | `~/.vim/` | shared by vim, neovim, IdeaVim |
| `vim/init.vim` | `~/.config/nvim/init.vim` | sources `~/.vim/vimrc` |
| `vim/.ideavimrc` | `~/.ideavimrc` | sources `~/.vim/vimrc`, adds `J`/`K` tabs |
| `mise/config.toml` | `~/.config/mise/config.toml` | used via `plugins/bjb-channels-repo-config` |

**`not-loaded/`:** files in `~` that the shell most likely never reads, so
what they set is probably not in effect. Kept because the setting inside may
still be wanted.

| File here | Lives at | Why not loaded |
|---|---|---|
| `not-loaded/.zprofile` | `~/.zprofile` | sets `JAVA_HOME`; with `ZDOTDIR=~/.zsh`, zsh reads `~/.zsh/.zprofile` instead |
| `not-loaded/.profile` | `~/.profile` | `brew shellenv`; bash/sh only |
| `not-loaded/.bash_profile` | `~/.bash_profile` | openssl on `PATH`; bash only |

Not copied: `~/.zsh/.zshrc`, the stock grml zshrc
(<https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc>), 130 KB, unmodified as
far as known; history, caches and `.zcompdump*`; credentials and tool state
(`gh`, `op`, `.kube`, `.docker`, `.m2`, `.claude*`); `karabiner` (ruled out).
