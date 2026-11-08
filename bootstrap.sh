#!/usr/bin/env bash
# bootstrap.sh — link this repo's hammerspoon/ into ~/.hammerspoon.
#
# Symlinks the three entries this repo owns (init.lua, config/, modules/).
# ~/.hammerspoon itself stays a real directory so Hammerspoon's own Spoons/
# is left untouched.
#
# Dry run by default. Nothing is written without --apply.
#
#   ./bootstrap.sh          # show what would change, and any drift
#   ./bootstrap.sh --apply  # back up what is there, then link
#
# Needs no admin rights. Reversible: the backup directory it prints holds the
# originals, and `unlink`ing the three entries and moving them back undoes it.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/hammerspoon"
DST="$HOME/.hammerspoon"
ENTRIES=(init.lua config modules)

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

say() { printf '%s\n' "$*"; }
run() { if (( APPLY )); then "$@"; else say "  would: $*"; fi; }

[[ -d "$SRC" ]] || { say "no $SRC — wrong directory?"; exit 1; }

say "repo: $SRC"
say "live: $DST"
say

# ---- drift check ------------------------------------------------------------
# If a live file differs from the repo copy, the symlink would discard it.
# Show that BEFORE touching anything.
drift=0
for e in "${ENTRIES[@]}"; do
  live="$DST/$e"
  [[ -e "$live" && ! -L "$live" ]] || continue
  if ! diff -rq "$live" "$SRC/$e" >/dev/null 2>&1; then
    drift=1
    say "DRIFT: $live differs from the repo copy:"
    # diff exits 1 on difference; under pipefail that would abort the script
    diff -ru "$SRC/$e" "$live" 2>&1 | sed 's/^/    /' | head -60 || true
    say
  fi
done
if (( drift )); then
  say "^ the live copy is NOT what this repo says it is."
  say "  Reconcile into the repo first (the backup below keeps the original,"
  say "  but the repo is what will be live afterwards)."
  say
fi

# ---- link -------------------------------------------------------------------
BACKUP="$DST/.backup-$(date +%Y%m%d-%H%M%S)"
need_backup=0
for e in "${ENTRIES[@]}"; do
  [[ -e "$DST/$e" || -L "$DST/$e" ]] && need_backup=1
done

run mkdir -p "$DST"
if (( need_backup )); then
  run mkdir -p "$BACKUP"
  say "backup: $BACKUP"
fi

for e in "${ENTRIES[@]}"; do
  live="$DST/$e"
  if [[ -L "$live" && "$(readlink "$live")" == "$SRC/$e" ]]; then
    say "ok:     $e already linked"
    continue
  fi
  if [[ -e "$live" || -L "$live" ]]; then
    run mv "$live" "$BACKUP/$e"
  fi
  run ln -s "$SRC/$e" "$live"
  say "link:   $e -> $SRC/$e"
done

say
if (( APPLY )); then
  say "done. Now: Hammerspoon menu → Reload Config, then re-verify"
  say "  caps+hjkl, lone-tap Escape, caps+space  (README.md, Verify)"
  say "and check .live/status.json in the repo — its \"watching\" field is the"
  say "directory the auto-reload watcher is on; it must be the repo path."
else
  say "dry run. re-run with --apply to make the changes above."
fi
