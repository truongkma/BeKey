#!/bin/sh
# ./build.sh  -> test engine + build build/BeKey.app (for packaging a release; install via Homebrew)
set -e
cd "$(dirname "$0")"
mkdir -p build

swiftc -swift-version 5 Sources/Engine.swift Tests/main.swift -o build/enginetest
./build/enginetest

APP=build/BeKey.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 Sources/*.swift -o "$APP/Contents/MacOS/BeKey"
cp Info.plist "$APP/Contents/"
[ -f build/icon.tiff ] || swift -swift-version 5 tools/icon.swift build/icon.tiff
cp build/icon.tiff "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "built $APP"
