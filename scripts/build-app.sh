#!/bin/bash
# Build on a Mac. This does not install a helper or change Screen Time settings.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ForE ScreenTime benötigt macOS zum Bauen (SwiftUI, AppKit und Accessibility)." >&2
    exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
command -v swift >/dev/null || { echo "Bitte Xcode 15+ bzw. Swift 5.9+ installieren." >&2; exit 1; }

swift build --configuration release --product ForEScreenTime
binary_dir="$(swift build --configuration release --show-bin-path)"
app_path="$project_dir/build/ForE ScreenTime.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_dir/ForEScreenTime" "$app_path/Contents/MacOS/ForEScreenTime"
cp "$project_dir/ForE/Resources/Info.plist" "$app_path/Contents/Info.plist"
chmod 755 "$app_path/Contents/MacOS/ForEScreenTime"

icons_dir="$(mktemp -d "${TMPDIR:-/tmp}/fore-screentime-icons.XXXXXX")"
trap 'rm -rf "$icons_dir"' EXIT
mkdir -p "$icons_dir/AppIcon.iconset"
assets_dir="$project_dir/ForE/Resources/Assets.xcassets/AppIcon.appiconset"
for size in 16 32 128 256 512; do
    cp "$assets_dir/AppIcon-${size}@1x.png" "$icons_dir/AppIcon.iconset/icon_${size}x${size}.png"
    cp "$assets_dir/AppIcon-${size}@2x.png" "$icons_dir/AppIcon.iconset/icon_${size}x${size}@2x.png"
done
iconutil --convert icns "$icons_dir/AppIcon.iconset" --output "$app_path/Contents/Resources/AppIcon.icns"
plutil -lint "$app_path/Contents/Info.plist"
codesign --force --sign - "$app_path"
codesign --verify --strict "$app_path"

echo "Fertig: $app_path"
echo "Die App ist lokal ad hoc signiert; keine Developer-ID-Signatur oder Notarisierung."
echo "Vor der Bedienungshilfenfreigabe an einen festen Ort verschieben, z. B. /Applications."
