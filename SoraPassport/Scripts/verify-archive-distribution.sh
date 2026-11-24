#!/bin/sh
set -e

# Archives are the only builds that can reach the App Store. A build or test
# run never needs these checks.
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
