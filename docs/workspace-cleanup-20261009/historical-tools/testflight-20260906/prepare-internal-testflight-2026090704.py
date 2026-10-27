#!/usr/bin/env python3
"""Prepare the exact four-file internal-TestFlight 2026090704 successor.

Required --source is a clean publication checkout whose HEAD equals --runtime.
That runtime must be the direct child of the actual dirty-tree validation base,
with every committed file equal to both snapshots from passed validation 3.
The default writes a reviewable patch and observation outside source. --apply
also applies those exact four unstaged files. It never commits, stages, pushes,
archives, uploads, reads secrets or changes any release/signing gate.
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
import stat
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
BASE = "70d0f1dc1139d6e2c05868fa6fb7ebddf7311c17"
VALIDATED_SOURCE = ROOT / "account-activation-recovery-ios"
PRIMARY = ROOT.parent / "sora-ios"
RUNTIME_PATHS = {
    "Fixtures/Modernization/ios-migration-qualification-README.md",
    "SoraPassport/Common/Extensions/SettingsExtension.swift",
    "SoraPassport/Common/Model/WalletNetworkModel.swift",
    "SoraPassport/ModulesRedesign/Root/RootInteractor.swift",
    "SoraPassport/ModulesRedesign/SplashScreen/SplashInteractor.swift",
    "SoraPassport/Scripts/collect-ios-migration-evidence.py",
    "SoraPassport/Scripts/test-ios-migration-evidence-collector.py",
    "SoraPassport/Scripts/verify-modernization-dependencies.sh",
    "SoraPassportTests/Common/Modernization/WalletModernizationTests.swift",
}
OLD_BASE = "e1c27842f4ee9e286bf9270cd7bd60d0352ed735"
OLD_UPSTREAM = "origin/codex/ios-wallet-upgrade-testflight-2026090703"
NEW_UPSTREAM = "origin/codex/ios-wallet-upgrade-testflight-2026090704"
OLD_BUILD = "2026090703"
NEW_BUILD = "2026090704"
OLD_LOWER_BOUND = "2026090702"
NEW_LOWER_BOUND = "2026090703"
PREFIX = "SoraPassport/Scripts/"
BASELINES = {
    PREFIX + "upload-ios-internal-testflight.sh": {
        "sha256": "6256a2ea4d324e4ebd2e92b141407a6f7d76dd6f655fce3f5eae7151f4df65f2",
        "counts": (1, 2, 3, 1),
    },
    PREFIX + "verify-modernization-dependencies.sh": {
        "sha256": "ac22fb8fe504952dd59e5a887bc2dc229f620958a134be7d4b1ca5029db1e7a2",
        "counts": (4, 2, 4, 0),
    },
    PREFIX + "verify-ios-internal-testflight-delivery.py": {
        "sha256": "af36c6e25d1668fca2727ccee12fe6f475c2a2229fd20505fd1b0d6f850b26b3",
        "counts": (0, 0, 1, 0),
    },
    PREFIX + "test-ios-internal-testflight-upload.py": {
        "sha256": "a010e2e64f4ddc127c5174496c19e60682b59703164a60e836a0382a887b783b",
        "counts": (2, 2, 9, 1),
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(source: Path, *arguments: str) -> bytes:
    return subprocess.check_output(["/usr/bin/git", "-C", str(source), *arguments])


def clean_runtime(source: Path, reviewed_base: str) -> None:
    require(source.is_absolute() and source.resolve(strict=True) == source,
            "Source must be an existing canonical absolute checkout path")
    require(git(source, "rev-parse", "--show-toplevel").decode().strip() == str(source),
            "Source must be the exact Git checkout root")
    require(source not in {VALIDATED_SOURCE, PRIMARY},
            "Preparation must use a separate publication checkout, never validated runtime or primary")
    require(git(source, "rev-parse", "HEAD").decode().strip() == reviewed_base,
            "Clean runtime HEAD must equal the provided full --runtime")
    require(git(source, "rev-list", "--parents", "-n", "1", reviewed_base).decode().split() == [reviewed_base, BASE],
            "Runtime must be one direct non-merge child of the recorded validation base")
    require(not git(source, "status", "--porcelain=v1", "--untracked-files=all"),
            "Runtime source must be completely clean before preparation/apply")


def tracked_snapshot(source: Path) -> dict[str, dict[str, str]]:
    snapshot = {}
    for entry in git(source, "ls-files", "--stage", "-z").split(b"\0"):
        if not entry:
            continue
        metadata, raw_name = entry.split(b"\t", 1)
        mode, blob, stage = metadata.decode().split()
        require(stage == "0", "Unmerged index entry is not permitted")
        name = raw_name.decode("utf-8")
        path = source / name
        if mode == "120000":
            data = os.readlink(path).encode("utf-8")
        elif mode == "160000":
            data = git(path, "rev-parse", "HEAD")
        else:
            require(path.is_file() and not path.is_symlink(),
                    f"Tracked source is missing or no longer regular: {name}")
            data = path.read_bytes()
        snapshot[name] = {"gitMode": mode, "sha256": sha(data)}
    return snapshot


def committed_source_hashes(directory, revision):
    """Hash Git blob bytes independently of status, skip-worktree flags or the checkout."""
    def tree(ref):
        result = {}
        for item in git(directory, 'ls-tree', '-r', '-z', '--full-tree', ref).split(b'\0'):
            if not item:
                continue
            metadata, raw_name = item.split(b'\t', 1)
            mode, kind, oid = metadata.decode().split()
            require(kind == 'blob' and mode in {'100644', '100755'},
                    'Runtime inventory must contain tracked regular files only')
            result[raw_name.decode()] = (mode, oid)
        return result
    baseline, runtime = tree(BASE), tree(revision)
    require(set(baseline) == set(runtime) and
            all(baseline[name][0] == runtime[name][0] for name in baseline),
            'Runtime must preserve the complete tracked path and mode inventory')
    result, cached = {}, {}
    process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=directory,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        for name, (_, oid) in runtime.items():
            if oid not in cached:
                process.stdin.write((oid + '\n').encode())
                process.stdin.flush()
                header = process.stdout.readline().decode().split()
                require(len(header) == 3 and header[:2] == [oid, 'blob'], 'Git blob lookup failed')
                size = int(header[2])
                data = process.stdout.read(size)
                require(len(data) == size and process.stdout.read(1) == b'\n', 'Git blob read was truncated')
                cached[oid] = sha(data)
            result[name] = cached[oid]
        process.stdin.close()
        require(process.wait(timeout=30) == 0, 'Git blob hash process failed')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        process.stdout.close()
        process.stderr.close()
    return result



def require_passed_validation(source: Path, runtime: str, observation: Path) -> tuple[dict, bytes]:
    raw = observation.read_bytes()
    observed = json.loads(raw)
    require(observed.get("status") == "passed", "Validation must be terminal passed before preparation")
    require(observed.get("sourceRevision") == BASE,
            "Preserve the actual dirty-tree validation base; never relabel it as the later runtime commit")
    committed = committed_source_hashes(source, runtime)
    checkout = {name: value["sha256"] for name, value in tracked_snapshot(source).items()}
    require(committed == checkout == observed.get("sourceAtStart") == observed.get("sourceAtEnd"),
            "Committed runtime and clean checkout must exactly match every tested file at start and end")
    changes = set(git(source, "diff", "--name-only", "-z", BASE, runtime).decode().strip("\0").split("\0"))
    require(changes == RUNTIME_PATHS, "Runtime correction must contain exactly the reviewed nine files")
    for label, count in [("focused-activation", 2), ("wallet-regressions", 247)]:
        result = observed.get(label, {})
        require(result.get("passedTests") == count and result.get("failedTests") == 0 and
                result.get("skippedTests") == 0, "Incomplete passing evidence: " + label)
    for label in ["build", "focused-activation", "wallet-regressions",
                  "focused-activation-summary", "wallet-regressions-summary"]:
        commands = [item for item in observed.get("commands", []) if item.get("label") == label]
        require(len(commands) == 1 and commands[0].get("exitCode") == 0 and commands[0].get("finishedAt") and
                Path(commands[0]["cwd"]).resolve() == VALIDATED_SOURCE,
                "Missing successful validation command from the actual tested checkout: " + label)
    require(observed.get("finishedAt"), "Validation requires its terminal timestamp")
    finished = datetime.fromisoformat(observed["finishedAt"].replace("Z", "+00:00"))
    committed_at = int(git(source, "show", "-s", "--format=%ct", runtime).decode().strip())
    require(finished.tzinfo is not None and committed_at >= int(finished.timestamp()),
            "Runtime commit must follow completed successful validation")
    return {
        "observation": str(observation), "observationSha256": sha(raw),
        "actualValidationSourceRevision": BASE, "validatedRuntimeCommit": runtime,
        "runtimeParent": BASE, "trackedFileCount": len(committed),
        "testedContentHashSetSha256": sha(json.dumps(committed, sort_keys=True).encode()),
        "buildPassed": True, "focusedActivationTestsPassed": 2, "walletRegressionTestsPassed": 247,
        "sourceRevisionMeaning": "dirty working-tree base; later commit bound through exact file content",
    }, raw


def render(name: str, original: bytes, reviewed_base: str) -> bytes:
    baseline = BASELINES[name]
    require(sha(original) == baseline["sha256"],
            f"Contract baseline bytes changed; inspect before repinning: {name}")
    text = original.decode("utf-8")
    tokens = (OLD_BASE, OLD_UPSTREAM, OLD_BUILD, OLD_LOWER_BOUND)
    require(tuple(text.count(token) for token in tokens) == baseline["counts"],
            f"Exact contract token occurrence counts changed: {name}")
    replacements = dict(zip(tokens, (reviewed_base, NEW_UPSTREAM, NEW_BUILD, NEW_LOWER_BOUND)))
    # One pass, longest token first. A newly introduced 0703 lower bound is never
    # processed again as an old build; the entire old upstream wins over its suffix.
    pattern = re.compile("|".join(re.escape(token) for token in sorted(tokens, key=len, reverse=True)))
    result = pattern.sub(lambda match: replacements[match.group(0)], text)
    require(result != text, f"Successor must modify each of the four contract files: {name}")
    require(OLD_BASE not in result and OLD_UPSTREAM not in result and OLD_LOWER_BOUND not in result,
            f"Obsolete source/upstream/lower-bound binding remains: {name}")
    require(tuple(result.count(token) for token in
                  (reviewed_base, NEW_UPSTREAM, NEW_BUILD, NEW_LOWER_BOUND)) == baseline["counts"],
            f"Successor token counts drifted or a lower-bound replacement cascaded: {name}")
    if name.endswith(".py"):
        ast.parse(result, filename=name)
    if name.endswith("test-ios-internal-testflight-upload.py"):
        require(result.count("    def test_") == text.count("    def test_"),
                "Existing upload test inventory must remain unchanged")
        require('"2026081602"' in result, "The invalid-build rejection fixture must remain")
    if name.endswith("upload-ios-internal-testflight.sh"):
        require(f'reviewed_lower_bound="{NEW_LOWER_BOUND}"' in result,
                "Consumed 0703 build must remain the lower bound")
        for option in ("-disableAutomaticPackageResolution", "-skipPackageUpdates"):
            require(result.count(option) == text.count(option) == 1,
                    f"Existing archive package freeze changed: {option}")
    return result.encode("utf-8")


def create_patch(originals: dict[str, bytes], replacements: dict[str, bytes]) -> bytes:
    parts = []
    for name in sorted(BASELINES):
        parts.append(f"diff --git a/{name} b/{name}\n")
        parts.extend(difflib.unified_diff(
            originals[name].decode().splitlines(keepends=True),
            replacements[name].decode().splitlines(keepends=True),
            fromfile=f"a/{name}", tofile=f"b/{name}", n=3,
        ))
    return "".join(parts).encode("utf-8")


def replace_regular(path: Path, expected: bytes, updated: bytes) -> None:
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and path.read_bytes() == expected,
            f"Contract changed before atomic apply: {path.name}")
    descriptor, temporary = tempfile.mkstemp(prefix=".testflight-0704-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            os.fchmod(stream.fileno(), stat.S_IMODE(info.st_mode))
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        require(path.read_bytes() == expected, f"Concurrent contract change: {path.name}")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path,
                        help="Canonical absolute clean runtime checkout; never a live test checkout")
    parser.add_argument("--runtime", "--reviewed-base", dest="reviewed_base", required=True,
                        help="Full 40-character SHA committed after successful validation, directly atop its recorded base")
    parser.add_argument("--observation", type=Path,
                        default=ROOT / "account-activation-recovery-validation-3/run-observation.json",
                        help="Successful actual validation observation; never rewritten by this preparer")
    parser.add_argument("--output-root", required=True, type=Path,
                        help="Absolute NEW private directory outside source for patch and evidence")
    parser.add_argument("--apply", action="store_true",
                        help="Also apply exactly four unstaged source files; no commit/stage/push")
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.reviewed_base) is not None
            and args.reviewed_base != OLD_BASE,
            "--runtime must be the new full lowercase runtime commit SHA")
    clean_runtime(args.source, args.reviewed_base)
    validation_observation = args.observation.resolve(strict=True)
    if validation_observation.is_dir():
        validation_observation = validation_observation / "run-observation.json"
    validation, validation_bytes = require_passed_validation(args.source, args.reviewed_base, validation_observation)
    require(args.output_root.is_absolute()
            and args.output_root.parent.resolve(strict=True) == args.output_root.parent,
            "Output must have a canonical existing absolute parent")
    require(all(not args.output_root.is_relative_to(path) for path in
                (args.source, VALIDATED_SOURCE, PRIMARY)), "Output must remain outside every source checkout")
    require(not args.output_root.exists() and not args.output_root.is_symlink(),
            "Output directory must be new; previous evidence must not be overwritten")
    for name in BASELINES:
        path = args.source / name
        require(path.is_file() and not path.is_symlink(),
                f"Contract input must be a regular non-symbolic file: {name}")
    originals = {name: (args.source / name).read_bytes() for name in BASELINES}
    replacements = {name: render(name, data, args.reviewed_base) for name, data in originals.items()}
    before = tracked_snapshot(args.source)
    require(sha(json.dumps({name: value["sha256"] for name, value in before.items()}, sort_keys=True).encode()) ==
            validation["testedContentHashSetSha256"],
            "Source bytes changed after validation content proof")
    for name in BASELINES:
        require(before[name]["gitMode"] in {"100644", "100755"},
                f"Contract input must be a tracked regular file: {name}")
    os.umask(0o077)
    args.output_root.mkdir(mode=0o700)
    patch = create_patch(originals, replacements)
    patch_path = args.output_root / "internal-testflight-2026090704.patch"
    patch_path.write_bytes(patch)
    record = {
        "preparedAt": datetime.now(timezone.utc).isoformat(),
        "source": str(args.source), "reviewedBase": args.reviewed_base,
        "validation": validation,
        "upstream": NEW_UPSTREAM, "build": NEW_BUILD, "lowerBound": NEW_LOWER_BOUND,
        "patchSha256": sha(patch), "applied": False,
        "staged": False, "committed": False, "pushed": False, "uploaded": False,
        "productionAuthorization": False,
        "files": {name: {"beforeSha256": sha(originals[name]),
                         "afterSha256": sha(replacements[name])} for name in sorted(BASELINES)},
        "trackedSourceBefore": before,
        "appliedPaths": [],
    }
    observation = args.output_root / "preparation-observation.json"
    def save() -> None:
        observation.write_text(json.dumps(record, indent=2) + "\n")
    save()
    try:
        # Parse shell without executing it, using copies outside the checkout.
        for name, data in replacements.items():
            if name.endswith(".sh"):
                check_path = args.output_root / Path(name).name
                check_path.write_bytes(data)
                subprocess.run(["/bin/sh", "-n", str(check_path)], check=True)
        subprocess.run(["/usr/bin/git", "-C", str(args.source), "apply", "--check", str(patch_path)], check=True)
        clean_runtime(args.source, args.reviewed_base)
        require(tracked_snapshot(args.source) == before,
                "Source changed during patch preparation; refusing any mutation")
        require(validation_observation.read_bytes() == validation_bytes,
                "Passed validation observation changed during preparation")
        if args.apply:
            for name in sorted(BASELINES):
                replace_regular(args.source / name, originals[name], replacements[name])
                record["appliedPaths"].append(name)
                save()
            require(git(args.source, "rev-parse", "HEAD").decode().strip() == args.reviewed_base,
                    "HEAD changed during apply")
            expected_diff = "".join("M\t" + name + "\n" for name in sorted(BASELINES)).encode()
            require(git(args.source, "diff", "--name-status", "--no-renames", "HEAD") == expected_diff,
                    "Applied diff is not exactly the four modified contract paths")
            expected_status = "".join(" M " + name + "\n" for name in sorted(BASELINES)).encode()
            require(git(args.source, "status", "--porcelain=v1", "--untracked-files=all") == expected_status,
                    "Unexpected staged, untracked, or unrelated source edits appeared")
            require(not git(args.source, "diff", "--cached", "--name-only"), "Nothing may be staged")
            expected_after = {name: dict(value) for name, value in before.items()}
            for name in BASELINES:
                expected_after[name]["sha256"] = sha(replacements[name])
            require(tracked_snapshot(args.source) == expected_after,
                    "Tracked source outside the four replacements changed")
            subprocess.run(["/usr/bin/git", "-C", str(args.source), "diff", "--check"], check=True)
            record["applied"] = True
            record["unchangedOtherTrackedFiles"] = len(before) - len(BASELINES)
            record["status"] = "applied-exact-four-unstaged-files"
        else:
            clean_runtime(args.source, args.reviewed_base)
            require(tracked_snapshot(args.source) == before, "Source changed during read-only preparation")
            record["status"] = "reviewable-patch-prepared-source-unchanged"
    except BaseException as error:
        record["status"] = "failed-evidence-preserved"
        record["errorClass"] = type(error).__name__
        # Do not automatically overwrite a concurrent edit or roll back the user's source.
        # If an apply failed mid-flight, appliedPaths and original hashes identify its state.
        raise
    finally:
        record["finishedAt"] = datetime.now(timezone.utc).isoformat()
        save()
    print(str(patch_path))
    print(str(observation))
    print(record["status"])


if __name__ == "__main__":
    main()
