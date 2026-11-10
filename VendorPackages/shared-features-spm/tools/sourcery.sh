# Generates mocks with Sourcery 2.1.3 (MIT, https://github.com/krzysztofzablocki/Sourcery).
# No prebuilt binary is kept in this repository: build it from source once, e.g.
#   git clone --branch 2.1.3 https://github.com/krzysztofzablocki/Sourcery.git && cd Sourcery && swift build -c release
# and put the resulting `sourcery` on PATH (or set SOURCERY to its path).
PROJECT_DIR="${WORKSPACE_PATH}/../../.."
SOURCERY="${SOURCERY:-$(command -v sourcery)}"
if [ -z "${SOURCERY}" ]; then
  echo "error: Sourcery is not on PATH; build it from source (see tools/sourcery.sh)" >&2
  exit 1
fi
"${SOURCERY}" --config "${PROJECT_DIR}/tools/sourcery.yml" --verbose
