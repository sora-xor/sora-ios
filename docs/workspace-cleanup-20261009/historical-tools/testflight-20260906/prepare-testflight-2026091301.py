#!/usr/bin/env python3
"""Prepare four publication pins for the verified startup-recovery successor.

Default: validate the committed runtime and completed 271-test receipt, then
write a review patch outside source. --apply additionally creates the fresh
1301 publication worktree/branch, applies exactly four pins, and runs the eight
existing publication tests and contract lint. Never commit, push, build, upload,
change export/signing/encryption policy, or claim device qualification.
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
BASE = "6afa083015a02eb12b1dade16d5be26f40018f33"
BUILD = "2026091301"
LOWER_BOUND = "2026090802"
BRANCH = "codex/ios-wallet-upgrade-testflight-" + BUILD
WORKTREE = ROOT / ("publish-" + BUILD + "-ios")
TOKENS = ("95d33aad697f476c6d8170e4a4303df779b3cc8b",
          "origin/codex/ios-wallet-upgrade-testflight-2026090802", "2026090802", "2026090801")
FILES = {
    "upload-ios-internal-testflight.sh": (1, 2, 3, 1),
    "verify-modernization-dependencies.sh": (4, 2, 4, 0),
    "verify-ios-internal-testflight-delivery.py": (0, 0, 1, 0),
    "test-ios-internal-testflight-upload.py": (2, 2, 9, 1),
}
SUITE_COUNTS = {"WalletModernizationTests": 229, "WalletRecoveryCapabilityGateTests": 11,
                "WalletRecoveryExporterTests": 12, "WalletUXTests": 19}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(source, *args):
    return subprocess.check_output(["/usr/bin/git", "-C", str(source), *args])


def snapshot(source):
    return {name: sha((source / name).read_bytes())
            for name in git(source, "ls-files", "-z").decode().split("\0")
            if name and (source / name).is_file()}


def render(source, runtime):
    replacements = dict(zip(TOKENS, (runtime, "origin/" + BRANCH, BUILD, LOWER_BOUND)))
    # One substitution pass prevents the new lower bound (old build) cascading.
    pattern = re.compile("|".join(re.escape(token) for token in sorted(TOKENS, key=len, reverse=True)))
    rendered, patch, changes = {}, [], {}
    for filename, counts in FILES.items():
        name = "SoraPassport/Scripts/" + filename
        raw = (source / name).read_bytes()
        original = raw.decode()
        require(tuple(original.count(token) for token in TOKENS) == counts,
                "Archive pin occurrence count changed: " + name)
        updated = pattern.sub(lambda match: replacements[match.group(0)], original)
        require(tuple(updated.count(token) for token in replacements.values()) == counts,
                "Pin replacement cascaded: " + name)
        if filename.endswith(".py"):
            ast.parse(updated, filename=name)
        else:
            subprocess.run(["/bin/sh", "-n"], input=updated.encode(), check=True)
        rendered[name] = updated.encode()
        changes[name] = {"beforeSha256": sha(raw), "afterSha256": sha(rendered[name])}
        patch.extend(difflib.unified_diff(original.splitlines(True), updated.splitlines(True),
                                         "a/" + name, "b/" + name))
    return rendered, patch, changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "connected-wallet-recovery-ios")
    parser.add_argument("--runtime", required=True, help="Full verified, committed runtime successor SHA")
    parser.add_argument("--validation", type=Path,
                        default=ROOT / "connected-wallet-recovery-validation-5/run-observation.json")
    parser.add_argument("--output", type=Path, default=ROOT / ("publication-preparation-" + BUILD))
    parser.add_argument("--apply", action="store_true", help="Create the fresh publication worktree and run checks")
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    output = args.output.resolve()
    require(source == (ROOT / "connected-wallet-recovery-ios").resolve(), "Use the isolated tested startup-recovery checkout")
    require(re.fullmatch(r"[0-9a-f]{40}", args.runtime), "A full verified runtime commit is required")
    require(git(source, "rev-parse", "--show-toplevel").decode().strip() == str(source), "Checkout root differs")
    require(git(source, "rev-list", "--parents", "-n", "1", "HEAD").decode().split() == [args.runtime, BASE],
            "Runtime must be the one committed successor of exact 0802 publication source")
    require(not git(source, "status", "--porcelain=v1", "--untracked-files=all"), "Runtime checkout must be clean")
    raw_validation = args.validation.read_bytes()
    validation = json.loads(raw_validation)
    require(validation.get("status") == "passed" and validation.get("sourceRevision") == BASE
            and validation.get("finishedAt"), "Require the terminal passed startup-recovery validation receipt")
    hashes = snapshot(source)
    require(hashes == validation.get("sourceAtStart") == validation.get("sourceAtEnd"),
            "Committed runtime differs from the complete tested file inventory")
    require(validation.get("expectedSuiteCounts") == SUITE_COUNTS, "Expected 271-test suite inventory differs")
    result = validation.get("wallet-regressions", {})
    require(result.get("passedTests") == 271 and result.get("failedTests") == 0 and result.get("skippedTests") == 0,
            "Require all 271 wallet tests passing without failures or skips")
    for label in ("build", "wallet-regressions", "wallet-regressions-summary"):
        commands = [item for item in validation.get("commands", []) if item.get("label") == label]
        require(len(commands) == 1 and commands[0].get("exitCode") == 0 and commands[0].get("finishedAt")
                and commands[0].get("cwd") == str(source), "Missing successful tested-source command: " + label)
    require(not output.exists() and source not in output.parents and output != source
            and WORKTREE not in output.parents and output != WORKTREE, "Use a fresh evidence directory outside source")
    require(not WORKTREE.exists() and not WORKTREE.is_symlink(), "Publication worktree already exists; preserve it")
    require(not git(source, "for-each-ref", "--format=%(refname)", "refs/heads/" + BRANCH).strip(),
            "Publication branch already exists; preserve it")
    rendered, patch, changes = render(source, args.runtime)
    os.umask(0o077)
    output.mkdir(mode=0o700, parents=True)
    (output / "publication-pins.patch").write_text("".join(patch))
    receipt = {"status": "prepared", "source": str(source), "publicationWorktree": str(WORKTREE),
        "publicationBranch": BRANCH, "runtimeRevision": args.runtime, "actualValidationSourceRevision": BASE,
        "validationReceipt": str(args.validation.resolve()), "validationReceiptSha256": sha(raw_validation),
        "testedTrackedFiles": len(hashes), "testedInventorySha256": sha(json.dumps(hashes, sort_keys=True).encode()),
        "passedWalletTests": 271, "buildNumber": BUILD, "observedConsumedLowerBound": LOWER_BOUND,
        "files": changes, "commands": [], "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "scope": "Four archive source pins; external TestFlight export remains a separate authorized step. "
                 "No commit, push, archive, upload, or physical-device qualification performed."}
    receipt_path = output / "preparation-observation.json"

    def save():
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")

    save()
    if args.apply:
        try:
            require(snapshot(source) == hashes and not git(source, "status", "--porcelain=v1", "--untracked-files=all"),
                    "Runtime changed before publication preparation")
            subprocess.run(["/usr/bin/git", "-C", str(source), "worktree", "add", "-b", BRANCH,
                            str(WORKTREE), args.runtime], check=True)
            # Keep source-root permissions equal to the tested checkout; only
            # retained delivery evidence uses the private mode0700 boundary.
            WORKTREE.chmod(source.stat().st_mode & 0o777)
            require(snapshot(WORKTREE) == hashes, "Fresh publication checkout differs from tested runtime")
            for name, raw in rendered.items():
                (WORKTREE / name).write_bytes(raw)
            expected = dict(hashes, **{name: sha(raw) for name, raw in rendered.items()})
            for label, command in [
                ("publication-tests", ["/usr/bin/python3", "-B", "-I", "-S",
                    str(WORKTREE / "SoraPassport/Scripts/test-ios-internal-testflight-upload.py")]),
                ("publication-contract-lint", ["/bin/sh",
                    str(WORKTREE / "SoraPassport/Scripts/upload-ios-internal-testflight.sh"), "--lint-contract"]),
                ("diff-check", ["/usr/bin/git", "-C", str(WORKTREE), "diff", "--check"]),
            ]:
                completed = subprocess.run(command, cwd=WORKTREE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                (output / (label + ".log")).write_bytes(completed.stdout)
                receipt["commands"].append({"label": label, "arguments": command, "exitCode": completed.returncode,
                    "log": str(output / (label + ".log")), "logSha256": sha(completed.stdout)})
                save()
                require(completed.returncode == 0, "Publication check failed: " + label)
                if label == "publication-tests":
                    require(re.search(rb"(?m)^Ran 8 tests in .+$", completed.stdout)
                            and re.search(rb"(?m)^OK$", completed.stdout), "Expected eight passing publication tests")
            require(set(git(WORKTREE, "diff", "--name-only").decode().splitlines()) == set(rendered),
                    "Publication patch must change exactly the four pin files")
            require(not git(WORKTREE, "diff", "--cached", "--name-only"), "Publication index must remain unstaged")
            require(not git(WORKTREE, "ls-files", "--others", "--exclude-standard"), "Unexpected publication files")
            require(snapshot(WORKTREE) == expected, "Publication source changed beyond the four exact pins")
            require(snapshot(source) == hashes and not git(source, "status", "--porcelain=v1", "--untracked-files=all"),
                    "Original runtime checkout changed")
            receipt.update(status="applied-and-verified", passedPublicationTests=8)
        except BaseException as error:
            receipt.update(status="failed", failure=str(error))
            save()
            raise
    save()
    print(json.dumps({"status": receipt["status"], "receipt": str(receipt_path),
                      "patch": str(output / "publication-pins.patch"), "files": len(changes)}))


if __name__ == "__main__":
    main()
