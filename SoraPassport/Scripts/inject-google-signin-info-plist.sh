#!/bin/sh
set -e

if [ -f "$PROJECT_DIR/SoraPassport/env-vars.sh" ]; then
  . "$PROJECT_DIR/SoraPassport/env-vars.sh"
fi

plist_buddy=/usr/libexec/PlistBuddy
app_info_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"

if [ ! -f "$app_info_plist" ]; then
  echo "error: Built Info.plist not found at $app_info_plist" >&2
  exit 1
fi

read_plist_value() {
  key="$1"
  plist="$2"

  "$plist_buddy" -c "Print :$key" "$plist" 2>/dev/null || true
}

firebase_config_path=""

for candidate in \
  "$PROJECT_DIR/$TARGET_NAME/Configs/${FIREBASE_CONFIG:-}" \
  "$PROJECT_DIR/SoraPassport/Configs/${FIREBASE_CONFIG:-}" \
  "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/GoogleService-Info.plist"
do
  if [ -f "$candidate" ]; then
    firebase_config_path="$candidate"
    break
  fi
done

if [ "$CONFIGURATION" = "Release" ]; then
  # Google Drive backups made by App Store 3.8.6 are visible only to the same
  # OAuth client. 3.8.6 took GIDClientID and its URL scheme from the
  # SORA_GOOGLE_TOKEN_DEV / SORA_GOOGLE_URL_SCHEME_DEV build settings (a
  # Jenkins credential, despite the name). Release uses exactly those
  # settings; any other source would silently switch the OAuth client.
  google_token="${SORA_GOOGLE_TOKEN_DEV:-}"
  google_url_scheme="${SORA_GOOGLE_URL_SCHEME_DEV:-}"
  for other in "${SORA_GOOGLE_TOKEN:-}" "${SORA_IOS_GOOGLE_TOKEN_PROD:-}"; do
    if [ -n "$other" ] && [ "$other" != "$google_token" ]; then
      echo "error: Release Google client ID must come only from SORA_GOOGLE_TOKEN_DEV (the 3.8.6 setting); another setting has a different value." >&2
      exit 1
    fi
  done
  if [ -z "$google_token" ] || [ -z "$google_url_scheme" ]; then
    if [ "$ACTION" = "install" ]; then
      echo "error: Release archives need SORA_GOOGLE_TOKEN_DEV and SORA_GOOGLE_URL_SCHEME_DEV with the values App Store 3.8.6 shipped, or existing Google Drive backups disappear for users." >&2
      exit 1
    fi
    echo "warning: SORA_GOOGLE_TOKEN_DEV is not set; this Release build uses the GoogleService-Info.plist client and must not be distributed." >&2
    google_token="$(read_plist_value CLIENT_ID "$firebase_config_path")"
    google_url_scheme="$(read_plist_value REVERSED_CLIENT_ID "$firebase_config_path")"
  fi
  # The callback scheme is the client ID with its components reversed.
  client_prefix="${google_token%.apps.googleusercontent.com}"
  if [ "$client_prefix" = "$google_token" ] || [ "$google_url_scheme" != "com.googleusercontent.apps.$client_prefix" ]; then
    echo "error: Google URL scheme does not match the Google client ID." >&2
    exit 1
  fi
else
  google_url_scheme="${SORA_GOOGLE_URL_SCHEME:-${SORA_GOOGLE_URL_SCHEME_DEV:-${SORA_IOS_GOOGLE_URL_SCHEME_PROD:-}}}"
  google_token="${SORA_GOOGLE_TOKEN:-${SORA_GOOGLE_TOKEN_DEV:-${SORA_IOS_GOOGLE_TOKEN_PROD:-}}}"

  if [ -z "$google_url_scheme" ] && [ -n "$firebase_config_path" ]; then
    google_url_scheme="$(read_plist_value REVERSED_CLIENT_ID "$firebase_config_path")"
  fi

  if [ -z "$google_token" ] && [ -n "$firebase_config_path" ]; then
    google_token="$(read_plist_value CLIENT_ID "$firebase_config_path")"
  fi
fi

if [ -z "$google_url_scheme" ]; then
  echo "error: Google URL scheme is not set and REVERSED_CLIENT_ID was not found in ${FIREBASE_CONFIG:-GoogleService-Info.plist}" >&2
  exit 1
fi

if [ -z "$google_token" ]; then
  echo "error: Google client ID is not set and CLIENT_ID was not found in ${FIREBASE_CONFIG:-GoogleService-Info.plist}" >&2
  exit 1
fi

"$plist_buddy" -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $google_url_scheme" "$app_info_plist"
"$plist_buddy" -c "Set :GIDClientID $google_token" "$app_info_plist"
