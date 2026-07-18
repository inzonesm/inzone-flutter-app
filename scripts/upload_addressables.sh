#!/bin/bash
# Uploads freshly-built Addressables artifacts (bundles + remote catalog)
# from the Unity ServerData/iOS folder to the inzone-unity-bundles GCS bucket,
# then updates Firestore unityGames docs with the new catalog filename.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated (gcloud auth login)
#   - service-account-key.json placed in scripts/ (deleted after, not committed)
#   - Node.js for the Firestore update step
#
# Usage:
#   ./scripts/upload_addressables.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UNITY_PROJECT="/Users/yxydw/Documents/inzone/Unity/My project"
SERVER_DATA="$UNITY_PROJECT/ServerData/iOS"
BUCKET="gs://inzone-unity-bundles/iOS"

echo "=== Uploading Addressables to GCS ==="

if [ ! -d "$SERVER_DATA" ]; then
    echo "ERROR: ServerData/iOS not found at $SERVER_DATA"
    echo "Run an Addressables build first (Build → New Build → Default Build Script)"
    exit 1
fi

# Find the latest catalog file (basename-safe for paths with spaces)
CATALOG_FILE=$(basename "$(ls -t "$SERVER_DATA"/catalog_*.bin 2>/dev/null | head -1)")
if [ -z "$CATALOG_FILE" ]; then
    echo "ERROR: No catalog_*.bin found in $SERVER_DATA"
    echo "Make sure m_BuildRemoteCatalog is enabled in AddressableAssetSettings."
    exit 1
fi

CATALOG_HASH="${CATALOG_FILE%.bin}.hash"
echo "Latest catalog: $CATALOG_FILE"
echo ""

# Upload bundles FIRST, catalog + hash LAST: the catalog is the pointer the
# app follows, so it must only flip once every bundle it references exists
# (otherwise live clients race a half-uploaded bucket and get 404s).
# gcloud storage, NOT gsutil: homebrew gsutil is broken on macOS/Python 3.12
# (multiprocessing fork-hang, then "sys has no attribute 'maxint'").
echo "[1/3] Uploading bundles to $BUCKET..."
gcloud storage rsync --recursive --exclude='catalog_.*|\.DS_Store' "$SERVER_DATA" "$BUCKET"

echo "[2/3] Publishing catalog..."
gcloud storage cp "$SERVER_DATA"/catalog_*.bin "$SERVER_DATA"/catalog_*.hash "$BUCKET/"

# Update Firestore with the catalog filename
if [ -f "$SCRIPT_DIR/service-account-key.json" ]; then
    echo ""
    echo "[3/3] Updating Firestore catalogFile for all games..."
    CATALOG_FILE="$CATALOG_FILE" node "$SCRIPT_DIR/update_catalog_field.js"
else
    echo ""
    echo "[3/3] SKIPPED — place service-account-key.json in scripts/ to auto-update Firestore."
    echo "Manually set 'catalogFile' to '$CATALOG_FILE' on each unityGames doc."
fi

echo ""
echo "=== Done! ==="
