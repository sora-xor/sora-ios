#!/usr/bin/env python3
"""Prepare four exact archive-contract pins after the lockout fix passes tests.

Writes a patch and receipt outside source; --apply changes only those four files
in a separate clean publication checkout. Never builds, uploads, commits, pushes,
changes encryption declarations, or asserts production qualification. External
TestFlight export is a separate, explicitly user-authorized publication step.
"""
import argparse
import ast
import datetime
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent
BASE = "ab0f3310fa9339c5716f09663ed53553d8ad3347"
TOKENS = ("e886d7cfacbff119cb9bcb961cfc213882675636",
          "origin/codex/ios-wallet-upgrade-testflight-2026090704", "2026090704", "2026090703")
FILES = {
    "upload-ios-internal-testflight.sh": (1, 2, 3, 1),
    "verify-modernization-dependencies.sh": (4, 2, 4, 0),
    "verify-ios-internal-testflight-delivery.py": (0, 0, 1, 0),
    "test-ios-internal-testflight-upload.py": (2, 2, 9, 1),
}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(source, *args):
    return subprocess.check_output(["/usr/bin/git", "-C", str(source), *args])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--runtime", required=True)
    parser.add_argument("--validation", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    output = args.output.resolve()
    require(re.fullmatch(r"[0-9a-f]{40}", args.runtime), "A full verified runtime commit is required")
    require(source not in {ROOT / "keychain-lockout-ios", ROOT.parent / "sora-ios"},
            "Use a separate publication checkout")
    require(git(source, "rev-parse", "--show-toplevel").decode().strip() == str(source), "Checkout root differs")
    require(git(source, "rev-list", "--parents", "-n", "1", "HEAD").decode().split() == [args.runtime, BASE],
            "Publication must start at the one runtime-fix successor of 0704 source")
    require(not git(source, "status", "--porcelain=v1", "--untracked-files=all"), "Publication checkout must be clean")
    raw_validation = args.validation.read_bytes()
    validation = json.loads(raw_validation)
    require(validation.get("status") == "passed" and validation.get("sourceRevision") == BASE,
            "Require completed validation with its actual dirty-tree base preserved")
    hashes = {name: sha((source / name).read_bytes())
              for name in git(source, "ls-files", "-z").decode().split("\0") if name}
    require(hashes == validation.get("sourceAtStart") == validation.get("sourceAtEnd"),
            "Clean committed runtime differs from the complete tested file inventory")
    for label, count in [("focused-recovery", 5), ("wallet-regressions", 253)]:
        result = validation.get(label, {})
        require(result.get("passedTests") == count and result.get("failedTests") == 0 and result.get("skippedTests") == 0,
                "Incomplete passing result: " + label)
    for label in ["build", "focused-recovery", "wallet-regressions"]:
        commands = [item for item in validation.get("commands", []) if item.get("label") == label]
        require(len(commands) == 1 and commands[0].get("exitCode") == 0 and commands[0].get("finishedAt"),
                "Missing successful command: " + label)
    require(validation.get("finishedAt"), "Validation has no terminal timestamp")
    replacements = dict(zip(TOKENS, (args.runtime,
        "origin/codex/ios-wallet-upgrade-testflight-2026090706", "2026090706", "2026090705")))
    pattern = re.compile("|".join(re.escape(token) for token in sorted(TOKENS, key=len, reverse=True)))
    rendered, patch, changes = {}, [], {}
    for filename, counts in FILES.items():
        name = "SoraPassport/Scripts/" + filename
        raw = (source / name).read_bytes()
        original = raw.decode()
        require(tuple(original.count(token) for token in TOKENS) == counts, "Archive pin occurrence count changed: " + name)
        updated = pattern.sub(lambda match: replacements[match.group(0)], original)
        require(tuple(updated.count(token) for token in replacements.values()) == counts, "Pin replacement cascaded: " + name)
        if filename.endswith(".py"):
            ast.parse(updated, filename=name)
        else:
            subprocess.run(["/bin/sh", "-n"], input=updated.encode(), check=True)
        rendered[name] = updated.encode()
        changes[name] = {"beforeSha256": sha(raw), "afterSha256": sha(rendered[name])}
        patch.extend(difflib.unified_diff(original.splitlines(True), updated.splitlines(True), "a/" + name, "b/" + name))
    require(not output.exists() and source not in output.parents, "Use a fresh output directory outside source")
    os.umask(0o077)
    output.mkdir(mode=0o700, parents=True)
    (output / "publication-pins.patch").write_text("".join(patch))
    if args.apply:
        for name, raw in rendered.items():
            require(sha((source / name).read_bytes()) == changes[name]["beforeSha256"], "Source changed before applying pins")
        for name, raw in rendered.items():
            (source / name).write_bytes(raw)
        subprocess.run(["git", "-C", str(source), "diff", "--check"], check=True)
    receipt = {"status": "applied" if args.apply else "prepared", "source": str(source),
        "runtimeRevision": args.runtime, "actualValidationSourceRevision": BASE,
        "validationReceipt": str(args.validation.resolve()), "validationReceiptSha256": sha(raw_validation),
        "testedTrackedFiles": len(hashes), "buildNumber": "2026090706", "observedConsumedLowerBound": "2026090705",
        "files": changes, "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "scope": "Archive source pins only; no build/upload/promotion or physical-device qualification performed"}
    (output / "preparation-observation.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"status": receipt["status"], "patch": str(output / "publication-pins.patch"), "files": len(changes)}))


if __name__ == "__main__":
    main()
