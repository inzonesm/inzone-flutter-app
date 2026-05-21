#!/usr/bin/env bash
#
# Create a new Shorebird release for the current pubspec version.
# Run ONCE per version bump in pubspec.yaml, before submitting the binary
# (IPA / AAB) to App Store Connect / Play Console.
#
# Usage:
#   ./scripts/shorebird_release.sh              # both platforms
#   ./scripts/shorebird_release.sh android
#   ./scripts/shorebird_release.sh ios
#
# Any extra args are forwarded to `shorebird release`, e.g.
#   ./scripts/shorebird_release.sh both -- --flavor=prod
set -euo pipefail

PLATFORM="${1:-both}"
shift || true
# Drop a leading "--" separator if present so remaining args pass through cleanly.
[[ "${1:-}" == "--" ]] && shift || true

VERSION=$(awk '/^version:/ {print $2; exit}' pubspec.yaml)
echo "==> Shorebird release for version ${VERSION} (platform: ${PLATFORM})"

run_release() {
  local platforms="$1"
  shorebird release --platforms="${platforms}" "$@"
}

case "$PLATFORM" in
  android) run_release android "$@" ;;
  ios)     run_release ios "$@" ;;
  both)
    run_release android "$@"
    run_release ios "$@"
    ;;
  *)
    echo "Usage: $0 [android|ios|both] [-- extra shorebird args]" >&2
    exit 1
    ;;
esac
