#!/bin/sh
set -e

# Symbol upload belongs to an archive, never a local build or test run.
[ "${ACTION:-}" = "install" ] || exit 0
case "${SORA_EVIDENCE_HARNESS_CONDITION:-} ${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-} ${OTHER_SWIFT_FLAGS:-} ${SORA_MIGRATION_EVIDENCE_HARNESS:-}" in
  *SORA_MIGRATION_EVIDENCE_HARNESS*)
    echo "error: migration evidence harness must not be archived for App Store distribution" >&2
    exit 1 ;;
esac
if [ -n "${SORA_MIGRATION_EVIDENCE_HARNESS:-}" ]; then
  echo "error: migration evidence harness must not be enabled for an archive" >&2
  exit 1
fi

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
if [ -n "${SORA_SOURCE_PACKAGES_PATH:-}" ]; then
  candidate="$SORA_SOURCE_PACKAGES_PATH/checkouts/firebase-ios-sdk/Crashlytics/run"
  if [ -f "$candidate" ]; then crashlytics_run="$candidate"; fi
fi

for start_dir in "${BUILD_DIR:-}" "${PROJECT_TEMP_DIR:-}" "${TARGET_TEMP_DIR:-}" "${PROJECT_DIR:-}"; do
  [ -z "$crashlytics_run" ] || break
  if [ -n "$start_dir" ]; then
    crashlytics_run="$(find_crashlytics_run "$start_dir")"

    if [ -n "$crashlytics_run" ]; then
      break
    fi
  fi
done


if [ -z "$crashlytics_run" ]; then
  echo "error: Firebase Crashlytics run script not found in Xcode SourcePackages" >&2
  exit 1
fi

# Bound the entire upload process group, including upload-symbols children.
# Xcode provides Python 3 through its command-line tools.
/usr/bin/python3 - "$crashlytics_run" <<'PYTHON'
import os
import signal
import subprocess
import sys

process = subprocess.Popen(["/bin/sh", sys.argv[1]], start_new_session=True)
try:
    sys.exit(process.wait(timeout=120))
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    print("error: Crashlytics symbol upload exceeded 120 seconds", file=sys.stderr)
    sys.exit(1)
PYTHON
