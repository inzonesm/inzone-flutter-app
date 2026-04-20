#!/usr/bin/env bash
#
# Push a Shorebird patch (live update) against an existing release.
# Safe to run as many times as you want — patches do not require a store rebuild.
# Patches can change Dart code only. They cannot change native code, pubspec
# assets, Flutter engine version, or anything that is baked into the binary.
#
# Usage:
#   ./scripts/shorebird_patch.sh                     # both platforms, latest release
#   ./scripts/shorebird_patch.sh android
#   ./scripts/shorebird_patch.sh ios 5.0.5
#   ./scripts/shorebird_patch.sh both 5.0.5
#
# Any extra args are forwarded to `shorebird patch`, e.g.
#   ./scripts/shorebird_patch.sh both latest -- --track=staging
set -euo pipefail

PLATFORM="${1:-both}"
RELEASE_VERSION="${2:-latest}"
shift || true
shift || true
[[ "${1:-}" == "--" ]] && shift || true

echo "==> Shorebird patch against release ${RELEASE_VERSION} (platform: ${PLATFORM})"

run_patch() {
  local platforms="$1"; shift
  shorebird patch \
    --platforms="${platforms}" \
    --release-version="${RELEASE_VERSION}" \
    "$@"
}

case "$PLATFORM" in
  android) run_patch android "$@" ;;
  ios)     run_patch ios "$@" ;;
  both)
    run_patch android "$@"
    run_patch ios "$@"
    ;;
  *)
    echo "Usage: $0 [android|ios|both] [release-version|latest] [-- extra shorebird args]" >&2
    exit 1
    ;;
esac
