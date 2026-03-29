#!/bin/bash
# Archive, Export, and Notarize Agent! app
# Based on Apple's documentation for customizing Xcode archive process

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ARCHIVE_PATH="$SCRIPT_DIR/build/Agent.xcarchive"
EXPORT_PATH="$SCRIPT_DIR/build/export"
APP_NAME="Agent!"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Step 1: Archive ===${NC}"
if [ -d "$ARCHIVE_PATH" ]; then
    echo "Archive already exists at $ARCHIVE_PATH"
else
    echo "Creating archive..."
    xcodebuild -scheme "Agent" -configuration Release -archivePath "$ARCHIVE_PATH" archive
fi

echo -e "${GREEN}=== Step 2: Export Archive ===${NC}"
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$SCRIPT_DIR/ExportOptions.plist" \
    -exportPath "$EXPORT_PATH"

APP_PATH=$(find "$EXPORT_PATH" -name "*.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}Error: No exported app found${NC}"
    exit 1
fi

echo -e "${GREEN}Exported app: $APP_PATH${NC}"

echo -e "${GREEN}=== Step 3: Create DMG for Notarization ===${NC}"
DMG_PATH="$EXPORT_PATH/${APP_NAME}.dmg"

# Create a temporary folder with the app
TMP_FOLDER="$EXPORT_PATH/dmg_temp"
rm -rf "$TMP_FOLDER"
mkdir -p "$TMP_FOLDER"
cp -R "$APP_PATH" "$TMP_FOLDER/"

# Create DMG
hdiutil create -srcfolder "$TMP_FOLDER" -format UDBZ -o "$DMG_PATH"
rm -rf "$TMP_FOLDER"

echo -e "${GREEN}DMG created: $DMG_PATH${NC}"

echo -e "${GREEN}=== Step 4: Submit for Notarization ===${NC}"
echo -e "${YELLOW}Note: You need to have stored App Store Connect credentials using:${NC}"
echo -e "${YELLOW}  xcrun notarytool store-credentials \"App Store Connect Profile\" --apple-id YOUR_APPLE_ID --team-id 469UCUB275 --password APP_SPECIFIC_PASSWORD${NC}"
echo ""

# Check if credentials are stored
CREDENTIAL_NAME="App Store Connect Profile"
if ! xcrun notarytool history -p "$CREDENTIAL_NAME" &>/dev/null; then
    echo -e "${RED}Error: Notarytool credentials not found.${NC}"
    echo ""
    echo "To set up notarization, run:"
    echo "  xcrun notarytool store-credentials \"$CREDENTIAL_NAME\" --apple-id YOUR_APPLE_ID --team-id 469UCUB275 --password YOUR_APP_SPECIFIC_PASSWORD"
    echo ""
    echo "Replace YOUR_APPLE_ID with your Apple ID email"
    echo "Replace YOUR_APP_SPECIFIC_PASSWORD with an app-specific password from appleid.apple.com"
    exit 1
fi

echo "Submitting DMG for notarization..."
xcrun notarytool submit -p "$CREDENTIAL_NAME" --wait --timeout 2h "$DMG_PATH"

echo -e "${GREEN}=== Step 5: Staple Ticket ===${NC}"
xcrun stapler staple "$APP_PATH"

echo -e "${GREEN}=== Complete! ===${NC}"
echo "Notarized app: $APP_PATH"
echo "DMG for distribution: $DMG_PATH"
open "$EXPORT_PATH"