#!/bin/bash
#
# patch.sh — Patch Apple's HP printer drivers for Apple Silicon & modern macOS
#
# Usage: ./patch.sh HewlettPackardPrinterDrivers.dmg
#
# Produces: HewlettPackardPrinterDrivers-patched.pkg in the current directory
#

set -euo pipefail

DMG="${1:-}"
OUTPUT="HewlettPackardPrinterDrivers-patched.pkg"
VOLUME_NAME="HP_PrinterSupportManual"
WORKDIR=""
MOUNTED=false

cleanup() {
    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        rm -rf "$WORKDIR"
    fi
    if $MOUNTED; then
        hdiutil detach "/Volumes/$VOLUME_NAME" -quiet 2>/dev/null || true
    fi
}
trap cleanup EXIT

# --- Validate input ---

if [ -z "$DMG" ]; then
    echo "Usage: $0 <HewlettPackardPrinterDrivers.dmg>"
    echo ""
    echo "Download the original DMG from Apple if you don't have it:"
    echo "  https://support.apple.com/kb/DL1888"
    exit 1
fi

if [ ! -f "$DMG" ]; then
    echo "Error: File not found: $DMG"
    exit 1
fi

# --- Check dependencies ---

for cmd in hdiutil xar sed; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' not found."
        exit 1
    fi
done

# --- Mount DMG ---

echo "Mounting $DMG..."
hdiutil attach "$DMG" -nobrowse -quiet
MOUNTED=true

PKG_PATH="/Volumes/$VOLUME_NAME/HewlettPackardPrinterDrivers.pkg"
if [ ! -f "$PKG_PATH" ]; then
    echo "Error: Expected package not found at $PKG_PATH"
    echo "Is this the correct HP printer drivers DMG?"
    exit 1
fi

# --- Extract package ---

WORKDIR=$(mktemp -d)
echo "Extracting package..."
cd "$WORKDIR"
xar -xf "$PKG_PATH"

if [ ! -f "Distribution" ]; then
    echo "Error: Distribution file not found in package."
    exit 1
fi

# --- Patch 1: Allow Apple Silicon (arm64) ---

if grep -q 'hostArchitectures="x86_64"' Distribution; then
    sed -i '' 's/hostArchitectures="x86_64"/hostArchitectures="x86_64,arm64"/' Distribution
    echo "Patched: Added arm64 to hostArchitectures"
elif grep -q 'hostArchitectures="x86_64,arm64"' Distribution; then
    echo "Already patched: arm64 support present"
else
    echo "Warning: Could not find hostArchitectures attribute to patch."
fi

# --- Patch 2: Remove macOS version cap ---

if grep -q "system.compareVersions" Distribution; then
    sed -i '' '/function InstallationCheck/,/^}/c\
function InstallationCheck(prefix) {\
    return true;\
}' Distribution
    echo "Patched: Removed macOS version cap from InstallationCheck()"
elif grep -q 'function InstallationCheck' Distribution; then
    echo "Already patched: InstallationCheck() returns true"
else
    echo "Warning: Could not find InstallationCheck function to patch."
fi

# --- Repackage ---

echo "Repackaging..."
xar -cf "$OLDPWD/$OUTPUT" ./*
cd "$OLDPWD"

echo ""
echo "Done! Patched package saved to: $OUTPUT"
echo ""
echo "To install, run:"
echo "  sudo installer -pkg $OUTPUT -target /"
echo ""
echo "Note: Apple Silicon Macs need Rosetta 2 installed:"
echo "  softwareupdate --install-rosetta"
