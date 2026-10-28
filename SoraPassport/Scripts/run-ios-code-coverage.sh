#!/bin/sh
set -eu

# Run on a disposable, caller-selected simulator. The unit suite contains the
# functional UIKit tests; the ordinary UI launch test verifies the built app host.
# Opt-in live/funded/evidence tests retain their existing admission checks.
if [ "$#" -ne 4 ]; then
    printf '%s\n' 'usage: run-ios-code-coverage.sh SIMULATOR_UDID DERIVED_DATA SOURCE_PACKAGES NEW_OUTPUT_DIRECTORY' >&2
    exit 2
fi
coverage_root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd -P)
coverage_simulator=$1
coverage_derived=$2
coverage_packages=$3
coverage_output=$4
if [ -e "$coverage_output" ]; then
    printf '%s\n' 'coverage output directory must not already exist' >&2
    exit 2
fi
mkdir -p "$coverage_output"
coverage_output=$(CDPATH= cd "$coverage_output" && pwd -P)
cd "$coverage_root"
python3 SoraPassport/Scripts/test-ios-code-coverage.py > "$coverage_output/gate-tests.log" 2>&1
python3 SoraPassport/Scripts/check-ios-code-coverage.py --write-source-manifest "$coverage_output/source-manifest.json"

# Use the test action, not test-without-building: Xcode must record its complete
# app-target source mapping. An empty report is rejected by the gate below.
xcodebuild test -project SoraPassport.xcodeproj -scheme SoraPassport -configuration Debug \
    -destination "platform=iOS Simulator,id=$coverage_simulator" \
    -derivedDataPath "$coverage_derived" -clonedSourcePackagesDirPath "$coverage_packages" \
    -onlyUsePackageVersionsFromResolvedFile -only-testing:SoraPassportTests \
    -only-testing:SoraPassportUITests/SoraPassportUITests \
    -parallel-testing-enabled NO -enableCodeCoverage YES -collect-test-diagnostics never -jobs 4 \
    -resultBundlePath "$coverage_output/application.xcresult" \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES ONLY_ACTIVE_ARCH=YES \
    > "$coverage_output/application.log" 2>&1
xcrun xccov view --report --json "$coverage_output/application.xcresult" > "$coverage_output/application.json"
xcrun xccov view --archive --json "$coverage_output/application.xcresult" > "$coverage_output/application-lines.json"
xcrun xcresulttool get test-results summary --path "$coverage_output/application.xcresult" \
    > "$coverage_output/test-summary.json"

coverage_codec="$coverage_root/VendorPackages/NexusTransferCodec"
swift test --package-path "$coverage_codec" --build-system native --enable-code-coverage \
    > "$coverage_output/codec.log" 2>&1
coverage_codec_report=$(swift test --package-path "$coverage_codec" --build-system native \
    --enable-code-coverage --show-codecov-path)
cp "$coverage_codec_report" "$coverage_output/codec.json"
python3 SoraPassport/Scripts/check-ios-code-coverage.py --write-source-manifest "$coverage_output/source-manifest-after.json"
cmp "$coverage_output/source-manifest.json" "$coverage_output/source-manifest-after.json"
python3 SoraPassport/Scripts/check-ios-code-coverage.py \
    --app-report "$coverage_output/application.json" --app-archive "$coverage_output/application-lines.json" \
    --app-manifest "$coverage_output/source-manifest.json" --codec-report "$coverage_output/codec.json" \
    --output "$coverage_output/production-summary.json"
