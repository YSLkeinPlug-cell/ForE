#!/bin/bash
# Build on a Mac. This does not install a helper or change Screen Time settings.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ForE ScreenTime benötigt macOS zum Bauen (SwiftUI, AppKit und Accessibility)." >&2
    exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
# A standalone Command Line Tools installation lacks the XCTest tools needed by
# SwiftPM. Select a full Xcode without changing the system's xcode-select setting.
selected_developer_dir=""
selected_sdkroot=""
try_developer_dir() {
    local candidate="${1:-}"
    local candidate_sdk
    [[ -n "$candidate" && -d "$candidate" ]] || return 1
    /usr/bin/env -u SDKROOT DEVELOPER_DIR="$candidate" /usr/bin/xcrun --find swift >/dev/null 2>&1 || return 1
    /usr/bin/env -u SDKROOT DEVELOPER_DIR="$candidate" /usr/bin/xcrun --sdk macosx --find xctest >/dev/null 2>&1 || return 1
    candidate_sdk="$(/usr/bin/env -u SDKROOT DEVELOPER_DIR="$candidate" /usr/bin/xcrun --sdk macosx --show-sdk-path 2>/dev/null)" || return 1
    [[ -d "$candidate_sdk" ]] || return 1
    selected_developer_dir="$candidate"
    selected_sdkroot="$candidate_sdk"
}

if ! try_developer_dir "${DEVELOPER_DIR:-}"; then
    active_developer_dir="$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p 2>/dev/null || true)"
    if ! try_developer_dir "$active_developer_dir" &&
       ! try_developer_dir "/Applications/Xcode.app/Contents/Developer" &&
       ! try_developer_dir "/Applications/Xcode-beta.app/Contents/Developer"; then
        cat >&2 <<'XCODE_HELP'
Kein vollständiges Xcode mit Swift, XCTest und macOS-SDK gefunden.
Bitte Xcode 15+ installieren und einmal öffnen. Unter
Xcode → Einstellungen → Locations → Command Line Tools die Xcode-Version wählen.
Alternativ nur für diesen Build den Pfad angeben:
DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer' bash scripts/build-app.sh
XCODE_HELP
        exit 1
    fi
fi

# These exports affect this script and its children only. In particular, replace
# an inherited CLT SDKROOT so Swift and the SDK come from the same selected Xcode.
export DEVELOPER_DIR="$selected_developer_dir"
export SDKROOT="$selected_sdkroot"
echo "Xcode: $DEVELOPER_DIR"
echo "macOS-SDK: $SDKROOT"

/usr/bin/xcrun swift build --configuration release --product ForEScreenTime
binary_dir="$(/usr/bin/xcrun swift build --configuration release --show-bin-path)"
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
