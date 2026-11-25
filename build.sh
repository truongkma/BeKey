#!/bin/sh
# ./build.sh          -> test engine + build build/BeKey.app
# ./build.sh install  -> also install into ~/Library/Input Methods and enable it
set -e
cd "$(dirname "$0")"
mkdir -p build

swiftc -swift-version 5 Sources/Engine.swift Tests/main.swift -o build/enginetest
./build/enginetest
swiftc -swift-version 5 Sources/Engine.swift Sources/InputController.swift Tests/controller/main.swift -o build/controllertest
./build/controllertest | tail -1

APP=build/BeKey.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 Sources/*.swift -o "$APP/Contents/MacOS/BeKey"
cp Info.plist "$APP/Contents/"
[ -f build/icon.tiff ] || swift -swift-version 5 tools/icon.swift build/icon.tiff
cp build/icon.tiff "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
# A second registered copy with the same bundle id makes macOS drop BeKey from the enabled
# input sources ("inactive", switches straight back to ABC): never leave the build copy registered.
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREG" -u "$APP" 2>/dev/null || true
echo "built $APP"

if [ "$1" = install ]; then
  DEST="${HOME:?}/Library/Input Methods/BeKey.app"
  pkill -x BeKey || true          # stop the old binary; relaunched below
  # Overwrite in place: deleting the bundle first makes Input Sources lose track of BeKey
  # (it stays listed but can no longer be selected until removed and re-added).
  mkdir -p "$DEST" && ditto "$APP" "$DEST"
  rm -rf "$APP"                   # same reason: no second copy of BeKey on disk
  "$DEST/Contents/MacOS/BeKey" --install || true
  open "$DEST" || true            # macOS does not always relaunch a killed input method by itself
fi
