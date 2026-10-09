#!/usr/bin/env python3
"""Rehearse a historical writer -> current wallet upgrade on a new simulator.

Every run creates its own simulator and output directory. The three test phases
are separate processes with explicit in-place app reinstalls between phases.
This runner never uninstalls an app, erases a simulator, signs an application,
uploads a build, or creates production qualification evidence.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import uuid


ROOT = Path(__file__).resolve().parents[2]
TARGET = "SoraPassportTests"
TEST = "HistoricalReleaseUpgradeTests/testPersistentUpgrade"
BUNDLE_ID = "co.jp.soramitsu.sora"
DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
SHARED_PACKAGES = Path(
    "/Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/"
    "ReleaseTests2-DerivedData/SourcePackages"
)
PHASES = ("produce", "migrate", "restart")


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def git(*arguments: str) -> bytes:
    return subprocess.check_output(["/usr/bin/git", "-C", str(ROOT), *arguments])


def source_snapshot() -> dict:
    changed = set(git("diff", "HEAD", "--name-only", "-z").split(b"\0"))
    changed.update(git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0"))
    hashes = {}
    for encoded in sorted(changed - {b""}):
        name = os.fsdecode(encoded)
        path = ROOT / name
        if path.is_symlink():
            hashes[name] = {"symlink": os.readlink(path)}
        elif path.is_file():
            hashes[name] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        else:
            hashes[name] = {"present": path.exists()}
    return {
        "repository": str(ROOT),
        "headCommit": git("rev-parse", "HEAD").decode().strip(),
        "headTree": git("rev-parse", "HEAD^{tree}").decode().strip(),
        "workingDiffSha256": hashlib.sha256(git("diff", "HEAD", "--binary")).hexdigest(),
        "changedAndUntrackedFiles": hashes,
    }


def target_name(key: str, target: dict) -> str:
    return target.get("TestTargetName", target.get("BlueprintName", key))


def phase_xctestrun(original: Path, phase: str, run_id: str) -> tuple[Path, dict]:
    value = plistlib.loads(original.read_bytes())
    matches = []
    if "TestConfigurations" in value:
        for configuration in value["TestConfigurations"]:
            for target in configuration.get("TestTargets", []):
                if target_name("", target) == TARGET:
                    matches.append((configuration, target))
        require(len(matches) == 1, "generated xctestrun must identify exactly one SoraPassportTests target")
        configuration, target = matches[0]
        copied_configuration = deepcopy(configuration)
        copied_target = deepcopy(target)
        copied_configuration["TestTargets"] = [copied_target]
        copied_configuration["IsEnabled"] = True
        copied = deepcopy(value)
        copied["TestConfigurations"] = [copied_configuration]
    else:
        for key, target in value.items():
            if isinstance(target, dict) and target_name(key, target) == TARGET:
                matches.append((key, target))
        require(len(matches) == 1, "generated xctestrun must identify exactly one SoraPassportTests target")
        key, target = matches[0]
        copied_target = deepcopy(target)
        copied = {key: copied_target}
        if "__xctestrun_metadata__" in value:
            copied["__xctestrun_metadata__"] = deepcopy(value["__xctestrun_metadata__"])

    arguments = copied_target.get("CommandLineArguments", [])
    require(isinstance(arguments, list) and "-UNITTEST" in arguments, "generated target must preserve the scheme's -UNITTEST launch argument")
    environment = copied_target.setdefault("EnvironmentVariables", {})
    require(isinstance(environment, dict), "generated test environment is malformed")
    environment.update({
        "SORA_HISTORICAL_WRITER_PHASE": phase,
        "SORA_HISTORICAL_WRITER_RUN_ID": run_id,
    })
    copied_target["OnlyTestIdentifiers"] = [TEST]
    copied_target["SkipTestIdentifiers"] = []
    require(copied_target["CommandLineArguments"] == target["CommandLineArguments"], "test launch arguments changed")

    # Keep __TESTROOT__ at the same Products directory as the original.
    destination = original.with_name(f"HistoricalWriter-{run_id}-{phase}.xctestrun")
    with destination.open("xb") as output:
        plistlib.dump(copied, output, sort_keys=False)
    return destination, {
        "original": str(original),
        "copy": str(destination),
        "copySha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
        "target": TARGET,
        "test": TEST,
        "commandLineArguments": arguments,
        "phaseEnvironment": {key: environment[key] for key in (
            "SORA_HISTORICAL_WRITER_PHASE", "SORA_HISTORICAL_WRITER_RUN_ID"
        )},
    }


class Run:
    def __init__(self, output_root: Path, derived_data: Path | None = None):
        self.output_root = output_root
        self.derived_data = derived_data or output_root / "DerivedData"
        self.record = {
            "schemaVersion": 1,
            "scope": "Disposable simulator rehearsal using a rebuilt historical account writer and current dependencies; not an original App Store binary or physical-device/production qualification.",
            "runId": str(uuid.uuid4()),
            "startedAt": now(),
            "status": "running",
            "sourceAtStart": source_snapshot(),
            "createdSimulator": None,
            "derivedData": str(self.derived_data),
            "commands": [],
            "phases": [],
        }
        self.save()

    def save(self) -> None:
        pending = self.output_root / "run-observation.json.tmp"
        pending.write_text(json.dumps(self.record, indent=2) + "\n")
        pending.replace(self.output_root / "run-observation.json")

    def command(self, label: str, arguments: list[str], *, allow_failure: bool = False) -> subprocess.CompletedProcess:
        log = self.output_root / f"{len(self.record['commands']) + 1:02d}-{label}.log"
        entry = {"label": label, "arguments": arguments, "cwd": str(ROOT), "startedAt": now(), "log": str(log)}
        self.record["commands"].append(entry)
        self.save()
        print(f"[{now()}] {label}", flush=True)
        with log.open("xb") as output:
            try:
                result = subprocess.run(arguments, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, check=False)
            except BaseException:
                entry["interruptedAt"] = now()
                self.save()
                raise
        entry.update({"finishedAt": now(), "exitCode": result.returncode})
        self.save()
        if result.returncode and not allow_failure:
            raise RuntimeError(f"{label} failed with exit {result.returncode}; inspect {log}")
        return result

    def execute(self) -> None:
        simulator = None
        try:
            self.command("verify-historical-provenance", [sys.executable, str(ROOT / "SoraPassport/Scripts/verify-ios-historical-writer-provenance.py")])
            name = f"SORA Historical Upgrade {self.record['runId']}"
            self.command("create-owned-simulator", ["/usr/bin/xcrun", "simctl", "create", name, DEVICE_TYPE, RUNTIME])
            creation_log = Path(self.record["commands"][-1]["log"])
            created = creation_log.read_text().strip()
            require(re.fullmatch(r"[0-9A-Fa-f-]{36}", created) is not None, "simctl create did not return one simulator UUID")
            simulator = str(uuid.UUID(created)).upper()
            self.record["createdSimulator"] = {"udid": simulator, "name": name, "deviceType": DEVICE_TYPE, "runtime": RUNTIME}
            self.save()
            self.command("boot-owned-simulator", ["/usr/bin/xcrun", "simctl", "boot", simulator])
            self.command("wait-owned-simulator-boot", ["/usr/bin/xcrun", "simctl", "bootstatus", simulator, "-b"])

            derived = self.derived_data
            destination = f"platform=iOS Simulator,id={simulator},arch=arm64"
            only_test = f"-only-testing:{TARGET}/{TEST}"
            build = [
                "/usr/bin/xcodebuild", "build-for-testing",
                "-project", str(ROOT / "SoraPassport.xcodeproj"), "-scheme", "SoraPassport",
                "-configuration", "Release", "-destination", destination,
                "-derivedDataPath", str(derived),
                "-resultBundlePath", str(self.output_root / "build.xcresult"),
                "-parallel-testing-enabled", "NO",
                "-maximum-concurrent-test-simulator-destinations", "1", only_test,
                "-disableAutomaticPackageResolution", "-skipPackageUpdates",
                "SORA_IOS_NONPROMOTING_RELEASE_TEST_MODE=sora-ios-nonpromoting-release-simulator-test-v1",
                "SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION=test",
                "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "ENABLE_TESTABILITY=YES",
                "ONLY_ACTIVE_ARCH=YES", "ARCHS=arm64", "EXCLUDED_ARCHS=x86_64",
            ]
            if SHARED_PACKAGES.is_dir():
                build.extend(["-clonedSourcePackagesDirPath", str(SHARED_PACKAGES)])
                self.record["sharedSourcePackages"] = str(SHARED_PACKAGES)
            self.command("build-for-testing", build)
            self.record["sourceAfterBuild"] = source_snapshot()
            require(self.record["sourceAfterBuild"] == self.record["sourceAtStart"], "source changed while building; evidence retained but this run cannot be attributed to one source snapshot")

            products = derived / "Build/Products"
            generated = [path for path in products.glob("*.xctestrun")
                         if not path.name.startswith("HistoricalWriter-")]
            require(len(generated) == 1, "build must produce exactly one original xctestrun")
            original = generated[0]
            app = products / "Release-iphonesimulator/SoraPassport.app"
            require(app.is_dir(), "built simulator application is missing")
            info = plistlib.loads((app / "Info.plist").read_bytes())
            require(info.get("CFBundleIdentifier") == BUNDLE_ID, "unexpected simulator application bundle identifier")
            executable = app / info["CFBundleExecutable"]
            self.record["builtApplication"] = {"path": str(app), "bundleIdentifier": BUNDLE_ID, "executableSha256": hashlib.sha256(executable.read_bytes()).hexdigest()}
            self.save()

            for index, phase in enumerate(PHASES):
                if index:
                    # XCTest may already have stopped the host; retain the exact
                    # termination result, then install over the existing app.
                    terminated = self.command(f"{phase}-terminate-host", ["/usr/bin/xcrun", "simctl", "terminate", simulator, BUNDLE_ID], allow_failure=True)
                    if terminated.returncode:
                        termination_output = Path(self.record["commands"][-1]["log"]).read_text().lower()
                        require(any(reason in termination_output for reason in (
                            "not running", "no such process", "found nothing to terminate"
                        )), "host termination failed for a reason other than an already-stopped process")
                    self.command(f"{phase}-install-over-existing", ["/usr/bin/xcrun", "simctl", "install", simulator, str(app)])
                phase_file, phase_record = phase_xctestrun(original, phase, self.record["runId"])
                result_bundle = self.output_root / f"{phase}.xcresult"
                phase_record.update({"phase": phase, "resultBundle": str(result_bundle), "status": "running"})
                self.record["phases"].append(phase_record)
                self.save()
                self.command(f"{phase}-test-without-building", [
                    "/usr/bin/xcodebuild", "test-without-building",
                    "-xctestrun", str(phase_file), "-destination", destination,
                    "-resultBundlePath", str(result_bundle),
                    "-parallel-testing-enabled", "NO",
                    "-maximum-concurrent-test-simulator-destinations", "1", only_test,
                ])
                self.command(f"{phase}-xcresult-summary", [
                    "/usr/bin/xcrun", "xcresulttool", "get", "test-results", "summary",
                    "--path", str(result_bundle), "--compact",
                ])
                summary_path = Path(self.record["commands"][-1]["log"])
                summary = json.loads(summary_path.read_bytes())
                phase_record["observedXCTestSummary"] = {
                    key: summary.get(key) for key in (
                        "result", "totalTestCount", "passedTests", "failedTests", "skippedTests"
                    )
                }
                require(
                    summary.get("result") == "Passed"
                    and summary.get("totalTestCount") == 1
                    and summary.get("passedTests") == 1
                    and summary.get("failedTests") == 0
                    and summary.get("skippedTests") == 0,
                    f"{phase} must execute and pass exactly one XCTest without failures or skips",
                )
                phase_record["status"] = "passed"
                self.save()

            self.record["sourceAtEnd"] = source_snapshot()
            require(self.record["sourceAtEnd"] == self.record["sourceAtStart"], "source changed during the rehearsal; inspect retained evidence")
            self.record["status"] = "three-phases-passed"
        except BaseException as error:
            self.record["status"] = "failed"
            self.record["failure"] = {"type": type(error).__name__, "message": str(error)}
            if self.record["phases"] and self.record["phases"][-1]["status"] == "running":
                self.record["phases"][-1]["status"] = "failed"
            raise
        finally:
            if simulator:
                # This UUID came from this run's successful create command.
                try:
                    self.command("shutdown-owned-simulator", ["/usr/bin/xcrun", "simctl", "shutdown", simulator], allow_failure=True)
                except BaseException as error:
                    self.record["shutdownError"] = str(error)
            self.record["finishedAt"] = now()
            self.record["retainedArtifacts"] = "Logs, result bundles, generated test plans and the dedicated simulator are retained; no uninstall, erase or deletion was performed."
            self.save()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="create a dedicated simulator and execute all three phases")
    parser.add_argument("--output-root", type=Path, help="absolute NEW output directory; existing parent required; created with mode 0700")
    parser.add_argument("--derived-data-path", type=Path,
                        help="optional existing rehearsal build cache outside the worktree; every run still rebuilds and verifies its source")
    arguments = parser.parse_args()
    if not arguments.run or arguments.output_root is None:
        parser.error("execution requires --run --output-root /absolute/new-directory")
    output = arguments.output_root
    require(output.is_absolute() and output != Path("/"), "output root must be an absolute non-root path")
    require(not output.exists() and not output.is_symlink(), "output root must be new; no overwrite is supported")
    require(output.parent.is_dir() and output.parent.resolve() == output.parent, "output parent must exist and use its canonical absolute path")
    require(output.parent.stat().st_uid == os.getuid(), "output parent must be owned by the current user")
    require(not output.is_relative_to(ROOT), "output root must stay outside the source worktree")
    derived = arguments.derived_data_path
    if derived is not None:
        require(derived.is_absolute() and derived.is_dir() and derived.resolve() == derived,
                "reused build cache must be an existing canonical absolute directory")
        require(not derived.is_relative_to(ROOT) and derived.stat().st_uid == os.getuid(),
                "reused build cache must be owned by the current user and outside the worktree")
    os.umask(0o077)
    output.mkdir(mode=0o700)
    run = Run(output, derived)
    run.execute()
    print(f"Three separate test phases completed. Inspect XCTest results and {output / 'run-observation.json'}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"Historical upgrade rehearsal failed: {error}", file=sys.stderr)
        sys.exit(1)
