#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
portal_dir="$project_root/server/public"

cd "$project_root"
flutter pub get
flutter build web --release --no-tree-shake-icons
rm -rf "$portal_dir/web"
cp -R build/web "$portal_dir/web"

echo "Web client copied to $portal_dir/web"
echo "Place these release files in $portal_dir/downloads before deploying:"
printf '%s\n' \
  "  lan-secure-messenger-windows.exe" \
  "  lan-secure-messenger-android.apk" \
  "  lan-secure-messenger-macos.dmg"