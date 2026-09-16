#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/Read.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/Read.iconset"
ASSET_BUILD_DIR="$ROOT_DIR/.build/AppIcon.xcassets"
ICON_SOURCE="$ROOT_DIR/Assets/noun-candle-4420273.png"

"$ROOT_DIR/Scripts/make-app-icon.sh"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.png"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$ROOT_DIR/.build/cache}"
export HOME="${HOME:-$ROOT_DIR/.build/home}"

swift build --disable-sandbox --product ReadApp

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/debug/ReadApp" "$MACOS_DIR/Read"
chmod +x "$MACOS_DIR/Read"

# iconutil rejects otherwise valid iconsets on newer macOS toolchains. Compile
# the generated icon renditions through Apple's asset-catalog compiler instead.
rm -rf "$ICONSET_DIR" "$ASSET_BUILD_DIR"
mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
  icon_file="$ICONSET_DIR/icon_${size}x${size}.png"
  sips -z "$size" "$size" "$ICON_SOURCE" --out "$icon_file" >/dev/null
  normalized_file="${icon_file%.png}.rgba.png"
  magick "$icon_file" -colorspace sRGB -alpha on -define png:color-type=6 "$normalized_file"
  mv "$normalized_file" "$icon_file"
  double_size=$((size * 2))
  icon_file="$ICONSET_DIR/icon_${size}x${size}@2x.png"
  sips -z "$double_size" "$double_size" "$ICON_SOURCE" --out "$icon_file" >/dev/null
  normalized_file="${icon_file%.png}.rgba.png"
  magick "$icon_file" -colorspace sRGB -alpha on -define png:color-type=6 "$normalized_file"
  mv "$normalized_file" "$icon_file"
done
cp -R "$ROOT_DIR/Assets/AppIcon.xcassets" "$ASSET_BUILD_DIR"
cp "$ICONSET_DIR"/* "$ASSET_BUILD_DIR/AppIcon.appiconset/"
"$DEVELOPER_DIR/usr/bin/actool" \
  --compile "$RESOURCES_DIR" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$CONTENTS_DIR/AssetInfo.plist" \
  "$ASSET_BUILD_DIR" >/dev/null

RESOURCE_BUNDLE="$ROOT_DIR/.build/debug/Read_ReadApp.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Read_ReadApp.bundle"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Read</string>
  <key>CFBundleExecutable</key>
  <string>Read</string>
  <key>CFBundleIdentifier</key>
  <string>app.read.prototype</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Read</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

echo "$APP_DIR"
