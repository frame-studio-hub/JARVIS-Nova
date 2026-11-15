#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/JARVISNova.app"
IDENTITY="E43E9DFB0FCC14241493725533968121E82FE13D"
cd "$ROOT"
swift build -c release
mkdir -p "$APP/Contents/MacOS"
cp .build/release/JARVISNova "$APP/Contents/MacOS/JARVISNova"
mkdir -p "$APP/Contents/Resources"
RESOURCE_BUNDLE=".build/out/Products/Release/JARVISNova_JARVISNova.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  rm -rf "$APP/Contents/Resources/JARVISNova_JARVISNova.bundle"
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
fi
chmod 755 "$APP/Contents/MacOS/JARVISNova"
/usr/libexec/PlistBuddy -c 'Set :NSAccessibilityUsageDescription JARVIS uses Accessibility to run your approved keyboard and mouse macros.' "$APP/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Add :NSAccessibilityUsageDescription string JARVIS uses Accessibility to run your approved keyboard and mouse macros.' "$APP/Contents/Info.plist"
codesign --force --deep --sign "$IDENTITY" --identifier com.framelab.jarvisnova "$APP"
codesign --verify --deep --strict "$APP"
echo "JARVIS built and signed with stable identity: $IDENTITY"