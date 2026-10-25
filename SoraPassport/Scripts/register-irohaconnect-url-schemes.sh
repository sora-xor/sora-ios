#!/bin/sh
# IrohaConnect is not part of App Store (Release) builds in 3.9.0: the app
# ignores its links there (ProductSurfacePolicy.acceptsIrohaConnect) and the
# production Info.plist does not register its URL schemes. Other
# configurations register them in the built Info.plist so testers can still
# open iroha:// and irohaconnect:// links.
set -e

if [ "$CONFIGURATION" = "Release" ]; then
  exit 0
fi

plist_buddy=/usr/libexec/PlistBuddy
app_info_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"

if [ ! -f "$app_info_plist" ]; then
  echo "error: Built Info.plist not found at $app_info_plist" >&2
  exit 1
fi

if "$plist_buddy" -c "Print :CFBundleURLTypes" "$app_info_plist" 2>/dev/null | grep -q "org.sora.irohaconnect"; then
  exit 0
fi

index="$(plutil -extract CFBundleURLTypes raw -o - "$app_info_plist")"

"$plist_buddy" \
  -c "Add :CFBundleURLTypes:$index dict" \
  -c "Add :CFBundleURLTypes:$index:CFBundleTypeRole string Viewer" \
  -c "Add :CFBundleURLTypes:$index:CFBundleURLName string org.sora.irohaconnect" \
  -c "Add :CFBundleURLTypes:$index:CFBundleURLSchemes array" \
  -c "Add :CFBundleURLTypes:$index:CFBundleURLSchemes:0 string iroha" \
  -c "Add :CFBundleURLTypes:$index:CFBundleURLSchemes:1 string irohaconnect" \
  "$app_info_plist"
