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

# Find the latest catalog file
CATALOG_FILE=$(ls -t "$SERVER_DATA"/catalog_*.bin 2>/dev/null | head -1 | xargs -n1 basename)
if [ -z "$CATALOG_FILE" ]; then
    echo "ERROR: No catalog_*.bin found in $SERVER_DATA"
    echo "Make sure m_BuildRemoteCatalog is enabled in AddressableAssetSettings."
    exit 1
fi

CATALOG_HASH="${CATALOG_FILE%.bin}.hash"
echo "Latest catalog: $CATALOG_FILE"
echo ""

# Upload everything in ServerData/iOS (bundles + catalog + hash)
echo "[1/2] Uploading to $BUCKET..."
gsutil -m rsync -r "$SERVER_DATA" "$BUCKET"

# Update Firestore with the catalog filename
if [ -f "$SCRIPT_DIR/service-account-key.json" ]; then
    echo ""
    echo "[2/2] Updating Firestore catalogFile for all games..."
    CATALOG_FILE="$CATALOG_FILE" node "$SCRIPT_DIR/update_catalog_field.js"
else
    echo ""
    echo "[2/2] SKIPPED — place service-account-key.json in scripts/ to auto-update Firestore."
    echo "Manually set 'catalogFile' to '$CATALOG_FILE' on each unityGames doc."
fi

echo ""
echo "=== Done! ==="
