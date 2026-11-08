#!/usr/bin/env bash
# env-check.sh — can this machine build and run the native overlay?
#
# Read-only apart from a throwaway Swift package in a temp directory, which is
# built, run and deleted. Writes its findings to
# docs/verification/YYYY-MM-DD-overlay-env-<machine>.md, in that folder's
# template, and prints the same to the terminal. Run it once per machine.
#
#   overlay/probes/env-check.sh            # machine = this Mac's local hostname
#   overlay/probes/env-check.sh work-new   # or name it yourself
#
# Never overwrites: a second run on the same day gets a -2, -3, ... suffix.
#
# Review the file before committing it: santactl and profiles may name your
# employer's sync or MDM server.

set -uo pipefail   # no -e: a failing check is a finding, not a reason to stop

MACHINE="${1:-$(scutil --get LocalHostName | tr '[:upper:]' '[:lower:]')}"
MODEL="$(sysctl -n hw.model)"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATE="$(date +%F)"
OUT="$REPO/docs/verification/$DATE-overlay-env-$MACHINE.md"
n=2
while [[ -e "$OUT" ]]; do
  OUT="$REPO/docs/verification/$DATE-overlay-env-$MACHINE-$n.md"
  n=$((n + 1))
done
SELF="overlay/probes/env-check.sh${1:+ $1}"

# Run a command, echoing it first; never fail.
run() {
  printf '$ %s\n' "$*"
  "$@" 2>&1
  printf '[exit %s]\n\n' "$?"
}

checks() {
  echo "== system"
  run sw_vers
  run uname -m
  run sysctl -n hw.model

  echo "== toolchain"
  run xcode-select -p
  # Without the tools, /usr/bin/swift pops up the installer instead of failing.
  # Skip the rest of the toolchain checks and the build rather than trigger it.
  local have_clt=1
  xcode-select -p >/dev/null 2>&1 || have_clt=0
  if (( ! have_clt )); then
    echo "no Command Line Tools: skipping toolchain checks and the build"; echo
  else
    run pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
    run ls /Library/Developer/CommandLineTools/SDKs
    run swift --version
    run xcrun --show-sdk-version
  fi

  echo "== policy"
  run spctl --status
  if command -v santactl >/dev/null; then
    run santactl status
  else
    echo "santactl: not installed"; echo
  fi
  run profiles status -type enrollment

  echo "== hammerspoon"
  run defaults read /Applications/Hammerspoon.app/Contents/Info.plist CFBundleShortVersionString

  # A minimal package: does swift build work, and may a binary built here run?
  # The second half is the Santa / allowlisting question in miniature.
  echo "== swift build smoke test"
  (( have_clt )) || { echo "skipped: no Command Line Tools"; return; }
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/Sources/smoke"
  cat > "$tmp/Package.swift" <<'EOF'
// swift-tools-version:5.9
import PackageDescription
let package = Package(
  name: "smoke",
  platforms: [.macOS(.v14)],
  targets: [.executableTarget(name: "smoke")]
)
EOF
  cat > "$tmp/Sources/smoke/main.swift" <<'EOF'
import AppKit
print("smoke ok, AppKit loaded:", NSApplication.shared.description.isEmpty == false)
EOF
  run swift build --package-path "$tmp" -c release
  run codesign -dv "$tmp/.build/release/smoke"
  run "$tmp/.build/release/smoke"
  rm -rf "$tmp"
}

output="$(checks)"
printf '%s\n' "$output"

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
# Overlay: can $MACHINE build and run a native Swift app?

- **Date:** $DATE
- **Question:** does a locally built Swift/AppKit binary build and run here, and what policy (Gatekeeper, Santa, MDM) applies?
- **Machine / keyboard:** $MACHINE ($MODEL), macOS $(sw_vers -productVersion), $(uname -m)

## Command

\`\`\`sh
$SELF
\`\`\`

## Output

\`\`\`
$output
\`\`\`

## Conclusion

*(to fill in)*
EOF

echo "wrote $OUT"
