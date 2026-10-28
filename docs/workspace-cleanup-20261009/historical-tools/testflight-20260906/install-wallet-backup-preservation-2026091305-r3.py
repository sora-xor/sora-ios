#!/usr/bin/env python3
"""Preserve the connected app container and install the verified development archive in place."""
import argparse, datetime, hashlib, json, os, plistlib, sqlite3, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parent
BUILD = "2026091305"
DEVICE = "E91E0F25-96F2-5CB6-A7CC-EB3435002556"
UDID = "00008150-000604420E38401C"
BUNDLE = "co.jp.soramitsu.sora"
SOURCE = ROOT / ("publish-" + BUILD + "-ios-r2")
ARCHIVE = ROOT / ("next-upload-" + BUILD + "-attempt-2") / ("SORA-" + BUILD + ".xcarchive")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--attempt", type=int, default=1, help="Positive attempt number; each attempt preserves a separate private receipt")
args = parser.parse_args()
assert 1 <= args.attempt <= 99
OUTPUT = ROOT / "connected-wallet-diagnosis-20260913" / ("install-" + BUILD + ("" if args.attempt == 1 else "-attempt-" + str(args.attempt)))
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def git(*args): return subprocess.check_output(["git", *args], cwd=SOURCE).decode().strip()
revision = git("rev-parse", "HEAD")
validation = json.loads((ROOT / "wallet-backup-preservation-validation-3/run-observation.json").read_text())
assert validation["status"] == "passed"
assert {k: validation["wallet-regressions"][k] for k in ("passedTests", "failedTests", "skippedTests")} == {"passedTests": 278, "failedTests": 0, "skippedTests": 0}
assert validation["sourceAtStart"] == validation["sourceAtEnd"]
runtime_record = json.loads((ROOT / "wallet-backup-preservation-evidence/runtime-commit-observation.json").read_text())
assert runtime_record["runtimeRevision"] == git("rev-parse", "HEAD^")
assert runtime_record["publicationRevision"] == revision
assert runtime_record["validationReceiptSha256"] == hashlib.sha256((ROOT / "wallet-backup-preservation-validation-3/run-observation.json").read_bytes()).hexdigest()
assert not git("status", "--porcelain")
archive_receipt = json.loads((ARCHIVE.parent / "archive-completion-observation.json").read_text())
assert archive_receipt["status"] == "archive-verified-awaiting-external-export"
assert archive_receipt["sourceRevision"] == revision
apps = list((ARCHIVE / "Products/Applications").glob("*.app")); assert len(apps) == 1
app = apps[0]; info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleVersion"] == BUILD and info["CFBundleIdentifier"] == BUNDLE
assert info["SoraMigrationEvidenceSourceRevision"] == revision
subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
entitlements = plistlib.loads(subprocess.check_output(["/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)], stderr=subprocess.DEVNULL))
assert entitlements["application-identifier"] == "YLWWUD25VZ." + BUNDLE
assert entitlements.get("get-task-allow") is True
profile = plistlib.loads(subprocess.check_output(["/usr/bin/security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")]))
assert UDID in profile["ProvisionedDevices"]
assert profile["Entitlements"]["application-identifier"] == "YLWWUD25VZ." + BUNDLE
os.umask(0o077); OUTPUT.mkdir(mode=0o700)
record = {"status": "preserving-container", "build": BUILD, "sourceRevision": revision, "startedAt": now(), "commands": [], "noUninstall": True}
def save(): (OUTPUT / "observation.json").write_text(json.dumps(record, indent=2) + "\n")
def command(label, args):
    with (OUTPUT / (label + ".log")).open("w") as stream:
        result = subprocess.run(["/usr/bin/xcrun", "devicectl", *args[:3], "--json-output", str(OUTPUT / (label + ".json")), *args[3:]], stdout=stream, stderr=subprocess.STDOUT)
    record["commands"].append({"label": label, "exitCode": result.returncode, "finishedAt": now()}); save()
    if result.returncode: raise RuntimeError(label + " failed; inspect private receipt")
    print(label + " succeeded", flush=True)
save()
try:
    container = OUTPUT / "before-install"; container.mkdir(mode=0o700)
    for folder in ["Documents", "Library"]:
        command("preserve-" + folder.lower(), ["device", "copy", "from", "--device", DEVICE,
            "--domain-type", "appDataContainer", "--domain-identifier", BUNDLE,
            "--source", folder, "--destination", str(container / folder)])
    databases = list(container.rglob("UserDataModel.sqlite"))
    assert len(databases) == 1, "Retained account database copy is missing or ambiguous"
    with sqlite3.connect(databases[0].as_uri() + "?mode=ro", uri=True) as database:
        assert database.execute("PRAGMA quick_check").fetchall() == [("ok",)]
        assert database.execute("SELECT COUNT(*) FROM ZCDACCOUNTITEM").fetchone()[0] >= 1
    record["preservedDatabaseIntegrityVerified"] = True
    record["preservedContainerHashes"] = {str(p.relative_to(container)): hashlib.sha256(p.read_bytes()).hexdigest() for p in container.rglob("*") if p.is_file()}
    record["status"] = "container-preserved"; save()
    command("install", ["device", "install", "app", "--device", DEVICE, str(app)])
    record["status"] = "installed-in-place"; save()
    command("launch", ["device", "process", "launch", "--device", DEVICE, BUNDLE])
    record["status"] = "installed-and-launched-awaiting-on-device-recovery"
except BaseException as error:
    record["failure"] = str(error); raise
finally:
    record["finishedAt"] = now(); save()
