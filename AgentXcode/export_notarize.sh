#!/bin/bash
# Export Archive and Notarize Agent! app

set -e

SCRIPT_DIR="/Users/toddbruss/Documents/GitHub/Agent/AgentXcode"
ARCHIVE_PATH="$SCRIPT_DIR/build/Agent.xcarchive"
EXPORT_PATH="$SCRIPT_DIR/build/export"
APP_NAME="Agent!"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Step 1: Export Archive ===${NC}"
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

echo -e "${GREEN}=== Step 2: Create ZIP for Notarization ===${NC}"
ZIP_PATH="$EXPORT_PATH/${APP_NAME}-notarize.zip"

# Use ditto to create a zip for notarization
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo -e "${GREEN}ZIP created: $ZIP_PATH${NC}"

echo -e "${GREEN}=== Step 3: Submit for Notarization ===${NC}"

CREDENTIAL_NAME="App Store Connect Profile"

# Check if credentials exist
if ! xcrun notarytool history -p "$CREDENTIAL_NAME" &>/dev/null; then
    echo -e "${RED}Error: Notarytool credentials not found.${NC}"
    echo ""
    echo "To set up notarization, run:"
    echo "  xcrun notarytool store-credentials \"$CREDENTIAL_NAME\" --apple-id YOUR_APPLE_ID --team-id 469UCUB275 --password YOUR_APP_SPECIFIC_PASSWORD"
    exit 1
fi

echo "Submitting for notarization..."
xcrun notarytool submit -p "$CREDENTIAL_NAME" --wait --timeout 2h "$ZIP_PATH"

echo -e "${GREEN}=== Step 4: Staple Ticket ===${NC}"
xcrun stapler staple "$APP_PATH"

echo -e "${GREEN}=== Complete! ===${NC}"
echo "Notarized app: $APP_PATH"
open "$EXPORT_PATH"