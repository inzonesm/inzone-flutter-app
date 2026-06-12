#!/bin/bash
# Builds UnityFramework from the Unity iOS export and copies it into the Flutter project.
#
# Usage: ./scripts/build_unity_framework.sh
#
# Prerequisites:
#   - Unity iOS build exported to $UNITY_BUILD_DIR
#     (override with UNITY_BUILD_DIR=/path/to/export ./scripts/build_unity_framework.sh)
#   - Xcode command line tools installed

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLUTTER_PROJECT="$(dirname "$SCRIPT_DIR")"
UNITY_BUILD_DIR="${UNITY_BUILD_DIR:-/Users/yxydw/Documents/inzone/unity_ios_build}"
FRAMEWORK_OUTPUT="$FLUTTER_PROJECT/ios/UnityFramework.framework"

echo "=== Building UnityFramework ==="
echo "Source:  $UNITY_BUILD_DIR"
echo "Output:  $FRAMEWORK_OUTPUT"
echo ""

# Check Unity build exists
if [ ! -d "$UNITY_BUILD_DIR/Unity-iPhone.xcodeproj" ]; then
    echo "ERROR: Unity iOS build not found at $UNITY_BUILD_DIR"
    echo "Export your Unity project for iOS first."
    exit 1
fi

# Build UnityFramework for device (arm64)
echo "[1/3] Building UnityFramework (Release, arm64)..."
xcodebuild \
    -project "$UNITY_BUILD_DIR/Unity-iPhone.xcodeproj" \
    -scheme UnityFramework \
    -configuration Release \
    -sdk iphoneos \
    -arch arm64 \
    -derivedDataPath "$UNITY_BUILD_DIR/DerivedData" \
    ONLY_ACTIVE_ARCH=NO \
    BUILD_DIR="$UNITY_BUILD_DIR/DerivedData/Build/Products" \
    -quiet

BUILT_FRAMEWORK="$UNITY_BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/UnityFramework.framework"

if [ ! -d "$BUILT_FRAMEWORK" ]; then
    echo "ERROR: Build succeeded but framework not found at $BUILT_FRAMEWORK"
    exit 1
fi

# Copy to Flutter project
echo "[2/4] Copying framework to Flutter project..."
rm -rf "$FRAMEWORK_OUTPUT"
cp -R "$BUILT_FRAMEWORK" "$FRAMEWORK_OUTPUT"

# Copy Data folder (IL2CPP metadata, assets, etc.) into the framework
echo "[3/4] Copying Unity Data folder into framework..."
if [ -d "$UNITY_BUILD_DIR/Data" ]; then
    cp -R "$UNITY_BUILD_DIR/Data" "$FRAMEWORK_OUTPUT/Data"
else
    echo "WARNING: Data folder not found at $UNITY_BUILD_DIR/Data"
    echo "The framework may crash at runtime without it."
fi

# Re-sign the framework
echo "[4/5] Signing framework..."
SIGN_IDENTITY=$(security find-identity -v -p codesigning | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -n "$SIGN_IDENTITY" ]; then
    codesign --force --sign "$SIGN_IDENTITY" "$FRAMEWORK_OUTPUT"
    echo "Signed with: $SIGN_IDENTITY"
else
    echo "WARNING: No signing identity found. Framework may crash on device."
fi

# Clean up DerivedData
echo "[5/5] Cleaning up build artifacts..."
rm -rf "$UNITY_BUILD_DIR/DerivedData"

echo ""
echo "=== Done! ==="
echo "UnityFramework.framework has been updated at:"
echo "  $FRAMEWORK_OUTPUT"
echo ""
echo "You can now build the Flutter app."
