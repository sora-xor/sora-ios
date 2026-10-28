#!/usr/bin/env python3
"""Generate, but never apply/stage/commit/push, the exact four-file successor patch.

Invoke after successful runtime tests have been committed. --runtime-base must
be the full SHA of that clean HEAD. The output repins only the existing internal
TestFlight contract and freezes package resolution for its archive command.
Protected release branches and production/reviewer approvals are not modified.
"""

from __future__ import annotations

import argparse
import ast
from datetime import datetime, timezone
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
BASE = Path(__file__).resolve().parent
DEFAULT_REPOSITORY = BASE / "historical-writer-ios"
OLD_BASE = "ffd14b0124bdc5a95ef33d7348d592ed4894665b"
OLD_UPSTREAM = "origin/release/testflight-2026090601"
NEW_UPSTREAM = "origin/codex/historical-writer-rehearsal-20260906"
OLD_BUILD = "2026090601"
NEW_BUILD = "2026090602"
OLD_LOWER_BOUND = "2026083101"
NEW_LOWER_BOUND = "2026090601"
PREFIX = "SoraPassport/Scripts/"
BASELINES = {
    PREFIX + "test-ios-internal-testflight-upload.py": {
        "sha256": "9aa610e0af39664fcbaea628b4516d885196a229f599975581218269bb03d4e2",
        "counts": (2, 2, 9, 1),
    },
    PREFIX + "upload-ios-internal-testflight.sh": {
        "sha256": "46682c3d09ecb0552eba3c67c20eeb514af652b9f9438574dd968ab3a1bd4e04",
        "counts": (1, 2, 3, 1),
    },
    PREFIX + "verify-ios-internal-testflight-delivery.py": {
        "sha256": "e0cd8ae4f261338d8fa30a2611ea90b5d840636dac5270654a93f52916fcb8a6",
        "counts": (0, 0, 1, 0),
    },
    PREFIX + "verify-modernization-dependencies.sh": {
        "sha256": "ddfc72e6f699addbb4fe1e66d6812dc32f3f46c3817ce2524db553599b4c419c",
        "counts": (4, 2, 4, 0),
    },
}
ARCHIVE_ANCHOR = '    -archivePath "${archive_path}" \\\n    -allowProvisioningUpdates \\\n'
ARCHIVE_REPLACEMENT = (
    '    -archivePath "${archive_path}" \\\n'
    '    -disableAutomaticPackageResolution \\\n'
    '    -skipPackageUpdates \\\n'
    '    -allowProvisioningUpdates \\\n'
)
TEST_ANCHOR = '        self.assertEqual(source.count("-allowProvisioningUpdates"), 1)\n'
TEST_REPLACEMENT = TEST_ANCHOR + '''        archive_command = source.split("if ! /usr/bin/xcodebuild", 1)[1].split(
            'archive >"${archive_log}"', 1
        )[0]
        for option in ("-disableAutomaticPackageResolution", "-skipPackageUpdates"):
            self.assertEqual(archive_command.count(option), 1)
'''


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(repository: Path, *arguments: str) -> bytes:
    return subprocess.check_output(["/usr/bin/git", "-C", str(repository), *arguments])


def replace_once(source: str, old: str, new: str, label: str) -> str:
    require(source.count(old) == 1, f"Expected exactly one unchanged {label} anchor")
    return source.replace(old, new, 1)


def render(path: str, original: bytes, runtime_base: str) -> bytes:
    baseline = BASELINES[path]
    require(sha256(original) == baseline["sha256"],
            f"Baseline bytes drifted for {path}; inspect rather than expanding replacements")
    source = original.decode("utf-8")
    tokens = (OLD_BASE, OLD_UPSTREAM, OLD_BUILD, OLD_LOWER_BOUND)
    counts = tuple(source.count(token) for token in tokens)
    require(counts == baseline["counts"], f"Baseline constant counts changed for {path}")
    # Upstream first so the old build number inside the old branch is not
    # accidentally changed into an unintended release branch. Lower bound last
    # because its successor intentionally equals the consumed old build number.
    for old, new in ((OLD_BASE, runtime_base), (OLD_UPSTREAM, NEW_UPSTREAM),
                     (OLD_BUILD, NEW_BUILD), (OLD_LOWER_BOUND, NEW_LOWER_BOUND)):
        source = source.replace(old, new)
    require(OLD_BASE not in source and OLD_UPSTREAM not in source
            and OLD_LOWER_BOUND not in source, f"Obsolete baseline remains in {path}")
    if path == PREFIX + "upload-ios-internal-testflight.sh":
        source = replace_once(source, ARCHIVE_ANCHOR, ARCHIVE_REPLACEMENT, "archive command")
    elif path == PREFIX + "test-ios-internal-testflight-upload.py":
        source = replace_once(source, TEST_ANCHOR, TEST_REPLACEMENT, "existing upload test")
        require(source.count("    def test_") == original.decode().count("    def test_"),
                "Successor must retain the existing test method set")
    require(source.encode() != original, f"Expected a changed successor file: {path}")
    if path.endswith(".py"):
        ast.parse(source, filename=path)
    return source.encode("utf-8")


def patch_bytes(originals: dict[str, bytes], updated: dict[str, bytes]) -> bytes:
    pieces = []
    require(sorted(originals) == sorted(BASELINES) == sorted(updated),
            "Patch must contain exactly the four reviewed contract paths")
    for path in sorted(BASELINES):
        pieces.append(f"diff --git a/{path} b/{path}\n")
        pieces.extend(difflib.unified_diff(
            originals[path].decode().splitlines(keepends=True),
            updated[path].decode().splitlines(keepends=True),
            fromfile=f"a/{path}", tofile=f"b/{path}", n=3,
        ))
    return "".join(pieces).encode()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-base", required=True,
                        help="full lowercase 40-character SHA of the clean tested runtime HEAD")
    parser.add_argument("--repository", type=Path, default=DEFAULT_REPOSITORY,
                        help="canonical source repository; read-only")
    parser.add_argument("--output-root", type=Path, required=True,
                        help="absolute NEW directory outside source for the reviewable patch and manifest")
    args = parser.parse_args()
    runtime_base = args.runtime_base
    require(re.fullmatch(r"[0-9a-f]{40}", runtime_base) is not None
            and runtime_base != OLD_BASE, "Runtime base must be the new full commit SHA")
    repository = args.repository
    require(repository.is_absolute() and repository.resolve() == repository,
            "Repository must use its canonical absolute path")
    require(git(repository, "rev-parse", "--show-toplevel").decode().strip() == str(repository),
            "Repository root does not match exactly")
    require(git(repository, "rev-parse", "HEAD").decode().strip() == runtime_base
            and git(repository, "cat-file", "-t", runtime_base).strip() == b"commit",
            "Runtime base must name the current exact commit")
    require(not git(repository, "status", "--porcelain=v1", "--untracked-files=normal").strip(),
            "Commit the successfully tested runtime changes first; source must be clean")
    branch = git(repository, "symbolic-ref", "--quiet", "--short", "HEAD").decode().strip()
    require(branch == NEW_UPSTREAM.removeprefix("origin/"),
            "Preparation must use the selected internal testing branch")
    originals = {path: git(repository, "show", f"{runtime_base}:{path}") for path in BASELINES}
    for path, content in originals.items():
        require((repository / path).read_bytes() == content, f"Worktree file drifted: {path}")
    updated = {path: render(path, data, runtime_base) for path, data in originals.items()}
    patch = patch_bytes(originals, updated)
    output = args.output_root
    require(output.is_absolute() and output != Path("/") and not output.exists()
            and not output.is_symlink() and not output.is_relative_to(repository),
            "Output must be a NEW absolute directory outside source")
    require(output.parent.is_dir() and output.parent.resolve() == output.parent
            and output.parent.stat().st_uid == os.getuid(),
            "Output parent must exist, be canonical and belong to the current user")
    os.umask(0o077)
    output.mkdir(mode=0o700)
    patch_path = output / "internal-testflight-2026090602.patch"
    with patch_path.open("xb") as stream:
        stream.write(patch)
    check = subprocess.run(["/usr/bin/git", "-C", str(repository), "apply", "--check", str(patch_path)],
                           capture_output=True, text=True, check=False)
    manifest = {
        "schemaVersion": 1, "createdAt": datetime.now(timezone.utc).isoformat(),
        "scope": "Internal TestFlight preparation only; no apply/stage/commit/push/upload, protected-branch changes or reviewer/production approval.",
        "repository": str(repository), "runtimeBaseRevision": runtime_base,
        "requiredSuccessorUpstream": NEW_UPSTREAM, "buildNumber": NEW_BUILD,
        "appStoreBuildLowerBound": NEW_LOWER_BOUND,
        "patch": str(patch_path), "patchSha256": sha256(patch),
        "files": {path: {"beforeSha256": sha256(originals[path]),
                         "afterSha256": sha256(updated[path])} for path in sorted(BASELINES)},
        "gitApplyCheck": {"exitCode": check.returncode, "stdout": check.stdout, "stderr": check.stderr},
        "tests": "Successful runtime test results must be checked by the publishing task before invoking this generator. This generator does not manufacture test evidence.",
    }
    with (output / "preparation.json").open("x") as stream:
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    require(check.returncode == 0, f"Read-only git apply --check failed; inspect {output / 'preparation.json'}")
    require(git(repository, "rev-parse", "HEAD").decode().strip() == runtime_base
            and not git(repository, "status", "--porcelain=v1", "--untracked-files=normal").strip(),
            "Source changed while preparing the patch")
    with (output / "README.md").open("x") as stream:
        stream.write(
            f"Internal TestFlight build {NEW_BUILD} successor patch\n\n"
            f"Runtime parent: `{runtime_base}`. Required pushed upstream: `{NEW_UPSTREAM}`. "
            f"Observed App Store lower bound to confirm before upload: `{NEW_LOWER_BOUND}`.\n\n"
            "The patch changes exactly four existing contract files. It preserves the exact clean/pushed "
            "source, one-child/four-path checks, app/code/signing/profile identity checks, runtime dependency "
            "closure, export verification and `testFlightInternalTestingOnly=true`. The only additional "
            "archive behavior is disabling automatic package resolution and package updates, with assertions "
            "in the existing wrapper contract test.\n\n"
            "After reviewing the complete patch, apply it without staging, run the wrapper lint, the eight "
            "internal TestFlight contract tests and the required dependency checks. Commit these four files "
            "as one immediate child of the runtime parent; push that exact child to the required upstream "
            "before invoking the existing uploader with fresh private output paths. This document does not "
            "claim those actions or any upload have happened.\n"
        )
    print(f"Prepared {patch_path}; read-only apply check passed. Source and index were not changed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"TestFlight successor preparation failed: {error}", file=sys.stderr)
        sys.exit(1)
