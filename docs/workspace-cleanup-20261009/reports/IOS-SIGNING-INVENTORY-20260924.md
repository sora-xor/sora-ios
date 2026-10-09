# iOS production signing inventory — 2026-09-24

Read-only assessment of the clean candidate at
`/Users/takemiyamakoto/dev/sora-wallet/sora-ios-release-candidate-20260924`,
revision `e88dca749d5f5569a2bc0831b23dae0ab1b17ed2`. No archive, IPA,
signature, export, upload, or project edit was made during this assessment.

## Installed selection

- Xcode 27.0 (27A266a) is installed.
- `security find-identity -v -p codesigning` reports a valid Apple Distribution
  identity for Soramitsu Co., Ltd. / team `YLWWUD25VZ`, SHA-1
  `84AB95335BE14CAE9B050A353910F86FF2F9539B`. This is the exact certificate
  pinned by the release inventory and archive wrapper.
- The current Xcode profile cache is
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles` (12 decoded
  profiles); the older `~/Library/MobileDevice/Provisioning Profiles` path is
  absent. Exactly one cached profile has the pinned UUID
  `7ae520bc-599b-48ae-abfa-627eef530f0c`, pinned name, and raw SHA-256
  `19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93`.
  Its team, `YLWWUD25VZ.co.jp.soramitsu.sora` application identifier, and
  distribution certificate match the release inventory. It is an App Store
  distribution profile (no device list, `get-task-allow=false`) expiring
  2027-07-26 11:29:42 UTC.
- The `SoraPassport` target's checked-in Release settings remain automatic
  signing with `iPhone Developer`; the production bundle ID is
  `co.jp.soramitsu.sora`, team `YLWWUD25VZ`, with
  `SoraPassport/SoraPassport.entitlements`. The controlled archive wrapper
  overrides signing **for that archive command** with the pinned distribution
  certificate, profile UUID, and manual style. Its checked-in candidate export
  options also select the exact certificate/profile with `destination=export`.
  No project-signing edit is needed to select them through that route.
- The archive wrapper's read-only `--lint-contract` check passes at this source
  revision. It verifies the wrapper contract, not protected release admission.

## Release hold

The installed certificate and profile do **not** constitute an authorized
production IPA. The required pre-archive command,
`verify-ios-production-signing-identity.sh --verify-qualified`, currently exits
`1`: `protected environment variable IOS_SIGNING_IDENTITY_SOURCE_REVISION is
required`. No protected `IOS_SIGNING_IDENTITY_*` or `IOS_TAIRA_*` environment
names were present in this shell. The checked-in `*.blocked.json` signing
templates are intentionally non-authorizing.

The protected release controller must provide a fresh exact-revision,
dual-authority signed signing-selection and existing-App-Store-lineage receipt,
trust root, public keys/signatures, and protected pins/paths. The archive wrapper
also requires the independently admitted Taira deployment manifest, vendored
binary qualification, migration evidence authorization binding, and verified
App Store build-number lower bound. After admission, the owner should run the
controlled reproducible archive/export route and compare independently
produced IPAs as specified in the repository handoff. We cannot claim an
exact-head **qualified** signed archive or IPA from this shell yet. An ad hoc
Xcode archive would bypass the repository's release admission.

The non-authorizing source contract digest at this revision is
`d9993da68529a43b49b145dcf1a78c469df7d09995b3a0d2e4b61b2741f35810`.
The protected controller can use this output to pin the exact source contract;
the digest alone grants no release authority.

## Read-only reproduction

Run from the candidate directory. These commands do not print profile contents
or protected environment values:

```sh
git rev-parse HEAD
git status --porcelain=v1 --untracked-files=normal
xcodebuild -version
security find-identity -v -p codesigning

profile="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/7ae520bc-599b-48ae-abfa-627eef530f0c.mobileprovision"
shasum -a 256 "$profile"
python3 - "$profile" <<'PY'
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
import plistlib
import subprocess
import sys

raw = Path(sys.argv[1]).read_bytes()
decoded = subprocess.check_output(['/usr/bin/security', 'cms', '-D', '-i', sys.argv[1]])
p = plistlib.loads(decoded)
entitlements = p['Entitlements']
print('pinned UUID:', p['UUID'] == '7ae520bc-599b-48ae-abfa-627eef530f0c')
print('pinned raw SHA-256:', sha256(raw).hexdigest() == '19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93')
print('team:', p['TeamIdentifier'] == ['YLWWUD25VZ'])
print('application:', entitlements['application-identifier'] == 'YLWWUD25VZ.co.jp.soramitsu.sora')
print('distribution certificate:', any(sha256(c).hexdigest() == 'd830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb' for c in p['DeveloperCertificates']))
print('unexpired:', p['ExpirationDate'].replace(tzinfo=timezone.utc) > datetime.now(timezone.utc))
print('distribution entitlements:', entitlements.get('get-task-allow') is False and not p.get('ProvisionedDevices'))
PY

/bin/sh SoraPassport/Scripts/archive-ios-migration-candidate.sh --lint-contract
/bin/sh SoraPassport/Scripts/verify-ios-production-signing-identity.sh --print-contract-sha256
/bin/sh SoraPassport/Scripts/verify-ios-production-signing-identity.sh --verify-qualified
```

The final command is expected to fail closed until the protected controller
supplies the real receipt and trust material. The inventory and admission design
are documented in
`Fixtures/Modernization/ios-production-signing-identity-qualification-README.md`.
