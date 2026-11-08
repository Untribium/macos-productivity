#!/usr/bin/env bash
# env-check.sh — can this machine build and run the native overlay?
#
# Read-only apart from a throwaway Swift package in a temp directory, which is
# built, run and deleted. Writes its findings to
# docs/verification/YYYY-MM-DD-overlay-env-<label>.md, in that folder's
# template, and prints the same to the terminal.
#
#   overlay/probes/env-check.sh            # label defaults to "work"
#   overlay/probes/env-check.sh home
#
# Review the file before committing it: santactl and profiles may name your
# employer's sync or MDM server.

set -uo pipefail   # no -e: a failing check is a finding, not a reason to stop

LABEL="${1:-work}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATE="$(date +%F)"
OUT="$REPO/docs/verification/$DATE-overlay-env-$LABEL.md"
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

  echo "== toolchain"
  run xcode-select -p
  run pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
  run ls /Library/Developer/CommandLineTools/SDKs
  run swift --version
  run xcrun --show-sdk-version

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
# Overlay: can the $LABEL machine build and run a native Swift app?

- **Date:** $DATE
- **Question:** does a locally built Swift/AppKit binary build and run here, and what policy (Gatekeeper, Santa, MDM) applies?
- **Machine / keyboard:** $LABEL machine, macOS $(sw_vers -productVersion), $(uname -m)

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
