# vim and zsh config on work-old

- **Date:** 2026-11-13
- **Question:** what the live shell and editor config is on each machine, so
  the shell spike (`docs/backlog.md` › Shell) can combine them
- **Machine / keyboard:** work-old, macOS 26.7.1 (keyboard not relevant)

`~/.zsh/.zshrc.local` and `~/.zsh/plugins/autocompletions` are symlinks into
the old setup tree (`~/Data/tools/setup/shell/resources/`), so their contents
are there and are not repeated here. Symlinked plugins are skipped by the
script for the same reason.

## Command

```sh
sw_vers -productVersion
for f in ~/.zshenv ~/.zshrc ~/.zsh ~/.zsh/.zshrc ~/.zsh/.zshrc.local ~/.zsh/.zprofile ~/.zsh/plugins ~/.vimrc ~/.vim ~/.config/nvim ~/.ideavimrc; do
  ls -ld "$f" 2>&1
done
ls -l ~/.zsh/plugins ~/.vim ~/.config/nvim 2>&1
for f in ~/.zshenv ~/.zshrc ~/.zsh/.zprofile ~/.vimrc ~/.vim/vimrc ~/.vim/vimrc.local ~/.config/nvim/init.vim ~/.ideavimrc; do
  [ -f "$f" ] && { echo "==> $f <=="; cat "$f"; echo; }
done
for f in ~/.zsh/plugins/* ~/.zsh/.zshrc.local; do
  [ -L "$f" ] && continue
  [ -f "$f" ] && { echo "==> $f <=="; cat "$f"; echo; }
done
head -n 5 ~/.zsh/.zshrc 2>&1
```

## Output

```
26.7.1
-rw-r--r--  1 patrice.damian.marti  staff  15 Dec 13  2023 /Users/patrice.damian.marti/.zshenv
ls: /Users/patrice.damian.marti/.zshrc: No such file or directory
drwxr-xr-x  14 patrice.damian.marti  staff  448 Nov 13 11:41 /Users/patrice.damian.marti/.zsh
-rw-r--r--@ 1 patrice.damian.marti  staff  130257 Oct 12 11:04 /Users/patrice.damian.marti/.zsh/.zshrc
lrwxr-xr-x  1 patrice.damian.marti  staff  112 Dec 13  2023 /Users/patrice.damian.marti/.zsh/.zshrc.local -> /Users/patrice.damian.marti/Library/CloudStorage/OneDrive-Accenture/Data/tools/setup/shell/resources/zshrc.local
-rw-r--r--  1 patrice.damian.marti  staff  10 Jan  4  2024 /Users/patrice.damian.marti/.zsh/.zprofile
drwxr-xr-x  5 patrice.damian.marti  staff  160 Oct  5 17:11 /Users/patrice.damian.marti/.zsh/plugins
ls: /Users/patrice.damian.marti/.vimrc: No such file or directory
drwxr-xr-x  5 patrice.damian.marti  staff  160 Oct  2  2025 /Users/patrice.damian.marti/.vim
drwxr-xr-x  3 patrice.damian.marti  staff  96 Jan 11  2024 /Users/patrice.damian.marti/.config/nvim
-rw-r--r--  1 patrice.damian.marti  staff  69 Jan 17  2024 /Users/patrice.damian.marti/.ideavimrc
/Users/patrice.damian.marti/.config/nvim:
total 8
-rw-r--r--  1 patrice.damian.marti  staff  20 Jan 11  2024 init.vim

/Users/patrice.damian.marti/.vim:
total 16
-rw-r--r--  1 patrice.damian.marti  staff  865 Jun 21  2024 vimrc
-rw-r--r--  1 patrice.damian.marti  staff   41 Jan 11  2024 vimrc.local

/Users/patrice.damian.marti/.zsh/plugins:
total 16
lrwxr-xr-x  1 patrice.damian.marti  staff  124 Dec 13  2023 autocompletions -> /Users/patrice.damian.marti/Library/CloudStorage/OneDrive-Accenture/Data/tools/setup/shell/resources/plugins/autocompletions
-rwxr-xr-x  1 patrice.damian.marti  staff  119 Jan 17  2024 bjb-channels-repo-config
-rwxr-xr-x@ 1 patrice.damian.marti  staff  116 Oct  5 17:11 claude-profiles
==> /Users/patrice.damian.marti/.zshenv <==
ZDOTDIR=~/.zsh

==> /Users/patrice.damian.marti/.zsh/.zprofile <==
cd ~/Data

==> /Users/patrice.damian.marti/.vim/vimrc <==
" NOTE: this is sourced by neovim from ~/.config/nvim/init.vim

" line numbers
set number

" start scrolling 10 lines before hitting top/bottom line
set scrolloff=10

" tabs to spaces
set expandtab
set shiftwidth=4
set tabstop=4

" use system clipboard
set clipboard^=unnamed,unnamedplus

" use case-insensitive search when searching all-lowercase (but also replace...)
set ignorecase
set smartcase

" clear search highlightung using Enter or Space
nnoremap <silent> <CR> :noh<CR><CR>
nnoremap <silent> <Space> :noh<CR><Space>

" jump to beginning/end of line
nnoremap H ^
nnoremap L $

" navigate command history using C-j and C-k
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>

" use qq instead of q! to exit without saving
cnoreabbrev <expr> qq ((getcmdtype() is# ':' && getcmdline() is# 'qq')?('q!'):('qq'))

" load machine-specific config
source ~/.vim/vimrc.local

==> /Users/patrice.damian.marti/.vim/vimrc.local <==
"machine-specific customizations go here

==> /Users/patrice.damian.marti/.config/nvim/init.vim <==
source ~/.vim/vimrc

==> /Users/patrice.damian.marti/.ideavimrc <==
source ~/.vim/vimrc

nnoremap J :tabnext<CR>
nnoremap K :tabprev<CR>

==> /Users/patrice.damian.marti/.zsh/plugins/bjb-channels-repo-config <==
#!/bin/bash
# configuration required for BJB channels repository
eval "$(mise activate zsh)"
eval "$(direnv hook zsh)"

==> /Users/patrice.damian.marti/.zsh/plugins/claude-profiles <==
alias claude-acn='CLAUDE_CONFIG_DIR=~/.claude-acn claude'
alias claude-bjb='CLAUDE_CONFIG_DIR=~/.claude-bjb claude'

# Filename:      /etc/zsh/zshrc
# Purpose:       config file for zsh (z shell)
# Authors:       grml-team (grml.org), (c) Michael Prokop <mika@grml.org>
# Bug-Reports:   see http://grml.org/bugs/
# License:       This file is licensed under the GPL v2.
```

## Conclusion

work-old still runs the old setup as installed: `ZDOTDIR=~/.zsh`, stock grml
`.zshrc`, `zshrc.local` and `autocompletions` linked live from the old tree,
two local-only plugins (`mise`/`direnv` hooks for a work repo, Claude profile
aliases). One vimrc feeds vim, neovim (`init.vim`) and IdeaVim
(`.ideavimrc`, plus `J`/`K` for tabs); `vimrc.local` is empty. No vim plugins.

Settles nothing yet: input for the shell spike, to be combined with the same
dump from work-new.
