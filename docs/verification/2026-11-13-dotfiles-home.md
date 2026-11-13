# vim and zsh config on home

- **Date:** 2026-11-13
- **Question:** what the live shell and editor config is on each machine, so
  the shell spike (`docs/backlog.md` › Shell) can combine them
- **Machine / keyboard:** home (personal), macOS 27.0.1 (keyboard not relevant)

work-new has no shell or editor config yet, so this file and
`2026-11-13-dotfiles-work-old.md` are the two inputs. The layout here differs
from work-old (no `ZDOTDIR`, grml `.zshrc` straight in `~`), so the command is
adapted: the additions are edited into `~/.zshrc` under a `## CUSTOM` header
rather than kept in a `.zshrc.local`, and only that tail is dumped.
`~/.config/karabiner/karabiner.json` and `~/.gitconfig` came up in the same
sweep and are included.

## Command

```sh
sw_vers -productVersion
for f in ~/.zshenv ~/.zshrc ~/.zshrc.local ~/.zprofile ~/.zsh ~/.vimrc ~/.vim ~/.config/nvim ~/.ideavimrc ~/.config/karabiner/karabiner.json ~/.gitconfig; do
  ls -ld "$f" 2>&1
done
ls -l ~/.zsh ~/.vim ~/.config/nvim 2>&1
git -C ~/.zsh/zsh-autosuggestions log -1 --format='zsh-autosuggestions %h %cd' 2>&1
for f in ~/.zprofile ~/.vimrc ~/.config/nvim/init.vim ~/.ideavimrc ~/.config/karabiner/karabiner.json ~/.gitconfig; do
  [ -f "$f" ] && { echo "==> $f <=="; cat "$f"; echo; }
done
head -n 5 ~/.zshrc
wc -l < ~/.zshrc
echo "==> ~/.zshrc, from '## CUSTOM' to the end <=="
sed -n '/^## CUSTOM/,$p' ~/.zshrc
```

## Output

```
27.0.1
ls: /Users/gray/.zshenv: No such file or directory
-rw-r--r--  1 gray  staff  132364  3 Jan  2024 /Users/gray/.zshrc
ls: /Users/gray/.zshrc.local: No such file or directory
-rw-r--r--  1 gray  staff  43 21 Jul  2023 /Users/gray/.zprofile
drwxr-xr-x  3 gray  staff  96  2 Dec  2023 /Users/gray/.zsh
-rw-r--r--  1 gray  staff  274  1 Nov  2023 /Users/gray/.vimrc
drwxr-xr-x  3 gray  staff  96  1 Oct  2023 /Users/gray/.vim
drwxr-xr-x  3 gray  staff  96 30 Nov  2023 /Users/gray/.config/nvim
-rw-r--r--@ 1 gray  staff  1062  1 Oct  2023 /Users/gray/.ideavimrc
-rw-------  1 gray  staff  183 29 Aug 18:13 /Users/gray/.config/karabiner/karabiner.json
-rw-r--r--  1 gray  staff  115 17 Oct  2023 /Users/gray/.gitconfig
/Users/gray/.config/nvim:
total 8
-rw-r--r--  1 gray  staff  159  1 Nov  2023 init.vim

/Users/gray/.vim:
total 0

/Users/gray/.zsh:
total 0
drwxr-xr-x  27 gray  staff  864  2 Dec  2023 zsh-autosuggestions
zsh-autosuggestions c3d4e57 Thu Sep 7 08:58:48 2023 -0600
==> /Users/gray/.zprofile <==

eval "$(/opt/homebrew/bin/brew shellenv)"

==> /Users/gray/.vimrc <==
" switch tabs
"unmap J
nmap J :tabnext<CR>
"unmap K
nmap K :tabprev<CR>

" jump to beginning/end of line
"unmap H
nmap H ^
"unmap L
nmap L $

" line numbers
set number

" qq alias for q!
cnoreabbrev <expr> qq ((getcmdtype() is# ':' && getcmdline() is# 'qq')?('q!'):('qq'))


==> /Users/gray/.config/nvim/init.vim <==
" load base vimrc
source ~/.vimrc

" set clipboard
set clipboard+=unnamedplus

" clear search highlights with Enter
nnoremap <silent> <CR> :nohlsearch<CR><CR>

==> /Users/gray/.ideavimrc <==
" .ideavimrc is a configuration file for IdeaVim plugin. It uses
"   the same commands as the original .vimrc configuration.
" You can find a list of commands here: https://jb.gg/h38q75
" Find more examples here: https://jb.gg/share-ideavimrc

" Source your .vimrc
source ~/.vimrc

"" -- Suggested options --
" Show a few lines of context around the cursor. Note that this makes the
" text scroll if you mouse-click near the start or end of the window.
set scrolloff=5

" Do incremental searching.
set incsearch

" Don't use Ex mode, use Q for formatting.
map Q gq

" --- Enable IdeaVim plugins https://jb.gg/ideavim-plugins

" Highlight copied text
Plug 'machakann/vim-highlightedyank'
" Commentary plugin
Plug 'tpope/vim-commentary'


unmap +
nmap + <Action>(QuickJavaDoc)


"" -- Map IDE actions to IdeaVim -- https://jb.gg/abva4t
"" Map \r to the Reformat Code action
"map \r <Action>(ReformatCode)

"" Map <leader>d to start debug
"map <leader>d <Action>(Debug)

"" Map \b to toggle the breakpoint on the current line
"map \b <Action>(ToggleLineBreakpoint)

==> /Users/gray/.config/karabiner/karabiner.json <==
{
    "profiles": [
        {
            "name": "Default profile",
            "selected": true,
            "virtual_hid_keyboard": { "keyboard_type_v2": "ansi" }
        }
    ]
}
==> /Users/gray/.gitconfig <==
[user]
	name = Patrice Marti
[alias]
	ss = status --short
	ssh = status --short -- .
	sh = status -- .
	s = status

# Filename:      /etc/zsh/zshrc
# Purpose:       config file for zsh (z shell)
# Authors:       grml-team (grml.org), (c) Michael Prokop <mika@grml.org>
# Bug-Reports:   see http://grml.org/bugs/
# License:       This file is licensed under the GPL v2.
    4045
==> ~/.zshrc, from '## CUSTOM' to the end <==
## CUSTOM

# aliases
alias ...='cd ../../'
alias q='exit'
alias c='clear'
alias v=nvim
alias tf=terraform

# open command's stdout in vim, e.g. see echo hello, see !!
# (no buffer to avoid having to type :q!)
see() {
    "$@" | v +':setlocal buftype=nofile' -
}


# Use vi mode in terminal (and allow backspace)
# source: https://gist.github.com/LukeSmithxyz/e62f26e55ea8b0ed41a65912fbebbe52
bindkey -v '^?' backward-delete-char
export KEYTIMEOUT=1

# Yank to system clipboard
function vi-yank-clipboard {
    zle vi-yank
    echo "$CUTBUFFER" | pbcopy -i
}
zle -N vi-yank-clipboard
bindkey -M vicmd 'y' vi-yank-clipboard

# search using current command as prefix
# NOTE: this ignores the last char of the input due to vim cursor placement
bindkey -M viins '^J' down-line-or-search
bindkey -M viins '^K' up-line-or-search

# Use vim keys for navigation in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

# Change cursor shape for different vi modes
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

# CLI autocompletion
# autosuggest commands
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^[[Z' forward-word # shift-tab to accept

# Angular
source <(ng completion script)

# AWS
autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit
complete -C $(which aws_completer) aws

# terraform
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

# Docker/Kubernetes 
source <(docker completion zsh)
source <(minikube completion zsh)
source <(kubectl completion zsh)

# various
# disable emoji in minikube output
export MINIKUBE_IN_STYLE=0

## END OF FILE #################################################################
# vim:filetype=zsh foldmethod=marker autoindent expandtab shiftwidth=4
# Local variables:
# mode: sh
# End:

```

## Conclusion

home is an older, hand-edited version of the same setup: stock grml `.zshrc`
in `~` with a `## CUSTOM` block appended, no `ZDOTDIR`, no `.zshrc.local`.
The block overlaps with what `docs/backlog.md` › Shell lists from work-old's
`zshrc.local`: aliases (`...`, `q`, `c`, `v`, `tf`), `see` (the same idea as
`iv`: a command's output into nvim), vi mode with
`KEYTIMEOUT=1`, yank to `pbcopy`, `ctrl+j/k` prefix history search, hjkl in
the completion menu, cursor shapes, zsh-autosuggestions (a plain git clone in
`~/.zsh`, pinned at 2023-09) with `shift+tab` forward-word, completions for
ng, aws, terraform, docker, minikube, kubectl. Missing compared with that
list: the custom prompt, `ctrl+l` to accept a word, and completions for brew
and 1password. `.zprofile` only runs `brew shellenv`.

The vim side is split differently from work-old: `~/.vimrc` (not
`~/.vim/vimrc`) holds `J`/`K` tabs and `H`/`L`, and both nvim's `init.vim` and
`.ideavimrc` source it. So `J`/`K` for tabs lands in plain vim here too, not
only in IdeaVim. `init.vim` adds `qq`, the clipboard and Enter to clear
search highlights; `.ideavimrc` is the IdeaVim sample plus
vim-highlightedyank, vim-commentary, and `+` mapped to QuickJavaDoc. IntelliJ
IDEA is installed here; nvim is 0.9.4 from Homebrew.

Karabiner-Elements is installed but its config is empty (default profile, no
rules), so it does nothing here: nothing to carry over, and nothing that
competes with the fn layer.

Settles nothing yet: input for the shell review, together with work-old.
