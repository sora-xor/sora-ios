#!/usr/bin/env python3
"""Prepare the exact four-file internal-TestFlight 2026090702 successor.

Required --source is a clean runtime checkout whose HEAD equals --reviewed-base.
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
OLD_BASE = "6a36f498e3155be4294e90129166020ae7ca352b"
OLD_UPSTREAM = "origin/codex/ios-wallet-upgrade-testflight-2026090602"
NEW_UPSTREAM = "origin/codex/ios-wallet-upgrade-testflight-2026090702"
OLD_BUILD = "2026090602"
NEW_BUILD = "2026090702"
OLD_LOWER_BOUND = "2026090601"
NEW_LOWER_BOUND = "2026090701"
PREFIX = "SoraPassport/Scripts/"
BASELINES = {
    PREFIX + "upload-ios-internal-testflight.sh": {
        "sha256": "aa9fd473797f4ca71e45b7eae282e3f4f8ba4ff8c2a8a7fc5cf20c1ac2c5d011",
        "counts": (1, 2, 3, 1),
    },
    PREFIX + "verify-modernization-dependencies.sh": {
        "sha256": "0327ae0441b6b771e934688cd1ef5eb8e89aa1e2f15b64accb870bef3832ac8d",
        "counts": (4, 2, 4, 0),
    },
    PREFIX + "verify-ios-internal-testflight-delivery.py": {
        "sha256": "74570d4a8d66f32d89eec41b437e585cf533e2080e98042ee8899b4bca894914",
        "counts": (0, 0, 1, 0),
    },
    PREFIX + "test-ios-internal-testflight-upload.py": {
        "sha256": "02b7f39258e7aa6fd4127aa3d73cdd0c18def216d1c799ccfa33eb4a6062e9bc",
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
    require(git(source, "rev-parse", "HEAD").decode().strip() == reviewed_base,
            "Clean runtime HEAD must equal the provided full --reviewed-base")
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


def render(name: str, original: bytes, reviewed_base: str) -> bytes:
    baseline = BASELINES[name]
    require(sha(original) == baseline["sha256"],
            f"Contract baseline bytes changed; inspect before repinning: {name}")
    text = original.decode("utf-8")
    tokens = (OLD_BASE, OLD_UPSTREAM, OLD_BUILD, OLD_LOWER_BOUND)
    require(tuple(text.count(token) for token in tokens) == baseline["counts"],
            f"Exact contract token occurrence counts changed: {name}")
    replacements = dict(zip(tokens, (reviewed_base, NEW_UPSTREAM, NEW_BUILD, NEW_LOWER_BOUND)))
    # One pass, longest token first. A newly introduced 0602 lower bound is never
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
                "Consumed 0701 build must remain the lower bound")
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
    descriptor, temporary = tempfile.mkstemp(prefix=".testflight-0702-", dir=path.parent)
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
    parser.add_argument("--reviewed-base", required=True,
                        help="Full 40-character SHA of the clean tested runtime HEAD")
    parser.add_argument("--output-root", required=True, type=Path,
                        help="Absolute NEW private directory outside source for patch and evidence")
    parser.add_argument("--apply", action="store_true",
                        help="Also apply exactly four unstaged source files; no commit/stage/push")
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.reviewed_base) is not None
            and args.reviewed_base != OLD_BASE,
            "--reviewed-base must be the new full lowercase runtime commit SHA")
    clean_runtime(args.source, args.reviewed_base)
    require(args.output_root.is_absolute()
            and args.output_root.parent.resolve(strict=True) == args.output_root.parent,
            "Output must have a canonical existing absolute parent")
    require(not args.output_root.is_relative_to(args.source), "Output must remain outside source")
    require(not args.output_root.exists() and not args.output_root.is_symlink(),
            "Output directory must be new; previous evidence must not be overwritten")
    for name in BASELINES:
        path = args.source / name
        require(path.is_file() and not path.is_symlink(),
                f"Contract input must be a regular non-symbolic file: {name}")
    originals = {name: (args.source / name).read_bytes() for name in BASELINES}
    replacements = {name: render(name, data, args.reviewed_base) for name, data in originals.items()}
    before = tracked_snapshot(args.source)
    for name in BASELINES:
        require(before[name]["gitMode"] in {"100644", "100755"},
                f"Contract input must be a tracked regular file: {name}")
    os.umask(0o077)
    args.output_root.mkdir(mode=0o700)
    patch = create_patch(originals, replacements)
    patch_path = args.output_root / "internal-testflight-2026090701.patch"
    patch_path.write_bytes(patch)
    record = {
        "preparedAt": datetime.now(timezone.utc).isoformat(),
        "source": str(args.source), "reviewedBase": args.reviewed_base,
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
