#!/bin/sh
set -e

find_crashlytics_run() {
  search_dir="$1"

  while [ -n "$search_dir" ] && [ "$search_dir" != "/" ]; do
    candidate="$search_dir/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"

    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi

    next_dir="$(dirname "$search_dir")"
    if [ "$next_dir" = "$search_dir" ]; then
      break
    fi

    search_dir="$next_dir"
  done
}

crashlytics_run=""

for start_dir in "${BUILD_DIR:-}" "${PROJECT_TEMP_DIR:-}" "${TARGET_TEMP_DIR:-}" "${PROJECT_DIR:-}"; do
  if [ -n "$start_dir" ]; then
    crashlytics_run="$(find_crashlytics_run "$start_dir")"

    if [ -n "$crashlytics_run" ]; then
      break
    fi
  fi
done

if [ -z "$crashlytics_run" ]; then
  crashlytics_run="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run" -type f -print -quit 2>/dev/null || true)"
fi

if [ -z "$crashlytics_run" ]; then
  echo "error: Firebase Crashlytics run script not found in Xcode SourcePackages" >&2
  exit 1
fi

"$crashlytics_run"
