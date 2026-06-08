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
#
# The Flutter version is pinned below (FLUTTER_VERSION); override it per-run with
# the SHOREBIRD_FLUTTER_VERSION env var.
set -euo pipefail

PLATFORM="${1:-both}"
shift || true
# Drop a leading "--" separator if present so remaining args pass through cleanly.
[[ "${1:-}" == "--" ]] && shift || true

VERSION=$(awk '/^version:/ {print $2; exit}' pubspec.yaml)

# Flutter version Shorebird builds the release with.
#
# Pinned to 3.41.6 -- the version every prior successful release shipped on
# (e.g. 5.0.6+711) -- to dodge flutter/flutter#186810: Flutter 3.44.x omits
# libapp.so from the release AAB, so Shorebird aborts with "No architecture
# artifacts found to upload" and the resulting Android bundle would crash on
# launch. Verified locally 2026-06-05: a clean `flutter build appbundle
# --release` on 3.44.1 still ships an AAB with zero libapp.so entries, so this
# is a 3.44 toolchain bug, not a stale build. Keeping the pin equal to the live
# release's Flutter also keeps Shorebird patches compatible across the train.
#
# Override per-run:   SHOREBIRD_FLUTTER_VERSION=3.44.1 ./scripts/shorebird_release.sh
# Use Shorebird's default (no pin):  SHOREBIRD_FLUTTER_VERSION= ./scripts/shorebird_release.sh
# Remove this pin once Shorebird ships a Flutter > 3.44.1 that fixes the bug.
FLUTTER_VERSION="${SHOREBIRD_FLUTTER_VERSION-3.41.6}"

echo "==> Shorebird release for version ${VERSION} (platform: ${PLATFORM}${FLUTTER_VERSION:+, flutter ${FLUTTER_VERSION}})"

run_release() {
  local platforms="$1"; shift
  if [[ -n "${FLUTTER_VERSION}" ]]; then
    shorebird release --platforms="${platforms}" --flutter-version="${FLUTTER_VERSION}" "$@"
  else
    shorebird release --platforms="${platforms}" "$@"
  fi
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
