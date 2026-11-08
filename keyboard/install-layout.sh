#!/usr/bin/env bash
# install-layout.sh — install and enable the keyboard layouts this repo wants:
# US (ISO-safe) (custom, in this directory) and Swiss German (Apple's).
#
# Dry run by default. Nothing is written without --apply.
#
#   ./install-layout.sh          # show what is installed / enabled, and what would change
#   ./install-layout.sh --apply  # install, then enable what is missing
#
# Needs no admin rights and no developer tools (JXA via osascript).
# Enabling a custom layout needs the user's consent: a dialog, or a prompt in
# System Settings. Enabling an already enabled custom layout prompts again, so
# this script only asks for what is missing.
#
# "Enabled" is read from the preference files, not from the live input source
# list, which can be stale (docs/verification/2026-11-08-us-iso-fix-layout.md):
#   Apple layouts   com.apple.HIToolbox     AppleEnabledInputSources
#   custom layouts  com.apple.inputsources  AppleEnabledThirdPartyInputSources

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_FILE="US (ISO-safe).keylayout"
LAYOUT_SRC="$DIR/$LAYOUT_FILE"
LAYOUT_DST="$HOME/Library/Keyboard Layouts/$LAYOUT_FILE"

# id | KeyboardLayout ID | preference domain | display name
WANTED=(
  "org.unknown.keylayout.USISO-safe|-28417|com.apple.inputsources AppleEnabledThirdPartyInputSources|US (ISO-safe)"
  "com.apple.keylayout.SwissGerman|19|com.apple.HIToolbox AppleEnabledInputSources|Swiss German"
)

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

say() { printf '%s\n' "$*"; }

# ---- TIS via JXA ------------------------------------------------------------
# tis register PATH | tis enable ID
tis() {
  osascript -l JavaScript - "$@" <<'EOF' 2>&1 | grep -v -e '^Keyboard Layouts:' -e 'TISFileInterrogator' || true
ObjC.import('Carbon');
function run(argv) {
  const [action, arg] = argv;
  if (action === 'register')
    return 'register ' + $.TISRegisterInputSource($.NSURL.fileURLWithPath($(arg)));
  const key = ObjC.castRefToObject($.kTISPropertyInputSourceID);
  const filter = $.NSDictionary.dictionaryWithObjectForKey($(arg), key);
  const arr = ObjC.castRefToObject($.TISCreateInputSourceList(filter, true));
  // JXA bridges NSArray.count as a string
  if (Number(arr.count) !== 1) return 'not found: ' + arg;
  return 'enable ' + arg + ' -> OSStatus ' + $.TISEnableInputSource(arr.objectAtIndex(0));
}
EOF
}

# is_enabled "domain key" KLID
is_enabled() {
  local domain=${1% *} key=${1#* }
  defaults read "$domain" "$key" 2>/dev/null | grep -q "\"KeyboardLayout ID\" = \"\{0,1\}$2\"\{0,1\};"
}

# ---- keyboard type, for the report ------------------------------------------
kbd=$(osascript -l JavaScript -e 'ObjC.import("Carbon"); const t=$.LMGetKbdType(); const c={0x414E5349:"ANSI",0x49534F20:"ISO",0x4A495320:"JIS"}[$.KBGetLayoutType(t)]||"other"; t+" ("+c+")"')
say "keyboard type (last used keyboard): $kbd"
say

# ---- 1. install the file ----------------------------------------------------
[[ -f "$LAYOUT_SRC" ]] || { say "no $LAYOUT_SRC — wrong directory?"; exit 1; }
if [[ -f "$LAYOUT_DST" ]] && cmp -s "$LAYOUT_SRC" "$LAYOUT_DST"; then
  say "ok:      $LAYOUT_FILE installed"
else
  [[ -f "$LAYOUT_DST" ]] && say "DIFFERS: $LAYOUT_DST is not the repo copy" \
                         || say "missing: $LAYOUT_DST"
  if (( APPLY )); then
    mkdir -p "$(dirname "$LAYOUT_DST")"
    cp "$LAYOUT_SRC" "$LAYOUT_DST"
    say "         installed"
  else
    say "  would: copy it to ~/Library/Keyboard Layouts/"
  fi
fi
(( APPLY )) && tis register "$LAYOUT_DST" >/dev/null

# ---- 2. enable what is missing ----------------------------------------------
missing=()
for w in "${WANTED[@]}"; do
  IFS='|' read -r id klid pref name <<<"$w"
  if is_enabled "$pref" "$klid"; then
    say "ok:      $name enabled"
  else
    say "off:     $name"
    missing+=("$w")
  fi
done

# Anything enabled that is not wanted: report only. Removing the selected layout
# fails silently, and removing is a decision, not drift.
say
say "enabled now:"
{ defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null
  defaults read com.apple.inputsources AppleEnabledThirdPartyInputSources 2>/dev/null; } \
  | grep '"KeyboardLayout Name"' | sed 's/.*= /  /; s/;$//'

if (( ${#missing[@]} == 0 )); then
  say; say "nothing to enable."; exit 0
fi
if (( ! APPLY )); then
  say; say "dry run. re-run with --apply to enable the layouts marked off."; exit 0
fi

# wait_enabled SECONDS — poll until every missing layout is enabled
wait_enabled() {
  local i w id klid pref name
  for (( i = 0; i < $1; i++ )); do
    local all=1
    for w in "${missing[@]}"; do
      IFS='|' read -r id klid pref name <<<"$w"
      is_enabled "$pref" "$klid" || all=0
    done
    (( all )) && return 0
    sleep 1
  done
  return 1
}

say
for w in "${missing[@]}"; do
  IFS='|' read -r id klid pref name <<<"$w"
  say "$(tis enable "$id")"
done
say
say "A custom layout needs your consent: allow it in the dialog, or in the"
say "System Settings prompt. Waiting up to 60 s..."
if ! wait_enabled 60; then
  if pgrep -xq "System Settings"; then
    say "bringing System Settings to the front; approve the prompt there."
    open -a "System Settings"
    wait_enabled 60 || true
  fi
fi

say
if wait_enabled 1; then
  say "done: all layouts enabled. Check the Input menu, then the key left of 1:"
  say "  US (ISO-safe) should give \` and ~ on every keyboard."
else
  say "still off. Most likely the layout was installed after this login, so"
  say "System Settings cannot see it yet. Log out, log back in, and re-run"
  say "  $0 --apply"
fi
