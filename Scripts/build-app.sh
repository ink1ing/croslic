#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
build_dir="$project_root/Distribution/build"
app_path="$build_dir/Mac Efficiency Hub.app"
zip_path="$build_dir/Mac-Efficiency-Hub.zip"

if [[ -d /Applications/Xcode.app ]]; then
  developer_dir=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
else
  developer_dir=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}
fi

DEVELOPER_DIR="$developer_dir" swift build -c release --package-path "$project_root"

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$project_root/.build/release/MacEfficiencyHub" "$app_path/Contents/MacOS/MacEfficiencyHub"
cp "$project_root/Distribution/Info.plist" "$app_path/Contents/Info.plist"
ditto "$project_root/components" "$app_path/Contents/Resources/components"
# Tab shortcuts are implemented directly in the app, so the duplicate component is not distributed.
rm -rf "$app_path/Contents/Resources/components/protab"
# Matter dependencies are installed into Application Support on first use,
# keeping the distributed archive small and reproducible.
rm -rf "$app_path/Contents/Resources/components/matter-gateway/node_modules"
rm -rf "$app_path/Contents/Resources/components/matter-gateway/.matter-storage"
rm -f "$app_path/Contents/Resources/components/matter-gateway/devices.json"
rm -f "$app_path/Contents/Resources/components/matter-gateway/settings.json"

codesign --force --deep --sign - "$app_path"
rm -f "$zip_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"

print "Built: $app_path"
print "Archive: $zip_path"
