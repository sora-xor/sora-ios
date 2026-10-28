#!/usr/bin/env python3
"""Run a copied, signed simulator host after an observed entitlement failure.

This contingency does not build, modify original build products, or qualify a
production release. It requires a terminal historical rehearsal whose build
succeeded with unchanged source and whose producer failed, plus retained
missing-Keychain-entitlement evidence. Invoke with python3 -B.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import struct
import sys
import uuid

sys.dont_write_bytecode = True
BASE = Path(__file__).resolve().parent
SOURCE = BASE / "historical-writer-ios"
RUNNER = SOURCE / "SoraPassport/Scripts/run-ios-historical-writer-upgrade.py"
PROJECTOR = SOURCE / "SoraPassport/Scripts/derive-ios-migration-test-host.py"
ENTITLEMENTS = BASE / "SORA-2026090601.xcarchive.internal-testflight-control/signed-entitlements.plist"
EXPECTED_ENTITLEMENTS = {
    "application-identifier": "YLWWUD25VZ.co.jp.soramitsu.sora",
    "com.apple.developer.team-identifier": "YLWWUD25VZ",
    "get-task-allow": True,
}
APPLE_DEVELOPMENT_IDENTITY = "1F57A04EB10B3665696663CDA0DBD893CF7FE886"
ENTITLEMENT_FAILURE = re.compile(
    r"(?<!\d)-34018(?!\d)|errSecMissingEntitlement|missing[ -]+(?:keychain[ -]+)?entitlement|"
    r"(?:required|requisite) entitlement", re.IGNORECASE
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def inventory(directory: Path) -> dict:
    result = {}
    for current, directories, files in os.walk(directory, followlinks=False):
        for name in sorted(directories + files):
            path = Path(current) / name
            relative = path.relative_to(directory).as_posix()
            if path.is_symlink():
                require(path.resolve().is_relative_to(directory),
                        f"App contains a symlink outside its bundle: {relative}")
                result[relative] = {"symlink": os.readlink(path)}
            elif path.is_file():
                result[relative] = {"sha256": digest(path), "size": path.stat().st_size}
            elif path.is_dir():
                result[relative] = {"directory": True}
            else:
                raise ValueError(f"Unexpected bundle file type: {relative}")
    return result


def projection(module, executable: Path) -> dict:
    # Simulator-only equivalence: retain every byte before the terminal code
    # signature except the LC_CODE_SIGNATURE fields and __LINKEDIT size fields.
    # Apple codesign may leave residual allocation bytes after its SuperBlob;
    # record those bytes separately without changing the signed executable or
    # relaxing the repository's production Mach-O projector.
    data = executable.read_bytes()
    require(len(data) >= 32, "Simulator executable is truncated")
    magic, cpu, subtype, filetype, count, command_size, _, _ = struct.unpack_from("<8I", data)
    require(magic == 0xFEEDFACF and cpu == 0x0100000C and subtype == 0 and filetype == 2,
            "Simulator equivalence requires one thin arm64 executable")
    require(0 < count <= 1024 and 32 + command_size < len(data), "Invalid command bounds")
    cursor = 32
    signatures = []
    linkedits = []
    for _ in range(count):
        require(cursor + 8 <= 32 + command_size, "Truncated load command")
        command, length = struct.unpack_from("<II", data, cursor)
        require(length >= 8 and length % 8 == 0 and cursor + length <= 32 + command_size,
                "Invalid load-command extent")
        if command == 0x1D:
            require(length == 16, "Unexpected LC_CODE_SIGNATURE shape")
            offset, size = struct.unpack_from("<II", data, cursor + 8)
            signatures.append((cursor, offset, size))
        if command == 0x19 and data[cursor + 8:cursor + 24].rstrip(b"\0") == b"__LINKEDIT":
            require(length == 72, "Unexpected __LINKEDIT sections")
            _, vm_size, file_offset, file_size = struct.unpack_from("<4Q", data, cursor + 24)
            linkedits.append((cursor, vm_size, file_offset, file_size))
        cursor += length
    require(cursor == 32 + command_size and len(signatures) == len(linkedits) == 1,
            "Expected one complete command table, signature and __LINKEDIT")
    signature_command, offset, size = signatures[0]
    linkedit_command, vm_size, file_offset, file_size = linkedits[0]
    require(32 + command_size <= file_offset < offset and offset + size == len(data)
            and file_offset + file_size == len(data), "Signature must be terminal inside __LINKEDIT")
    require(vm_size == (file_size + 16383) // 16384 * 16384,
            "__LINKEDIT VM size must be exactly its arm64 page-rounded file size")
    signature = data[offset:]
    require(12 <= len(signature) <= module.MAX_SIGNATURE_BYTES, "Invalid signature bounds")
    signature_magic, declared_length, _ = struct.unpack_from(">III", signature)
    require(signature_magic == module.CSMAGIC_EMBEDDED_SIGNATURE
            and 12 <= declared_length <= len(signature), "Invalid signature SuperBlob")
    slots = module.parse_entitlements_blob(signature[:declared_length], str(executable))
    padding = signature[declared_length:]
    normalized = bytearray(data[:offset])
    ranges = [(signature_command + 8, 8), (linkedit_command + 32, 8),
              (linkedit_command + 48, 8)]
    for start, length in ranges:
        normalized[start:start + length] = bytes(length)
    return {
        "canonicalSha256": hashlib.sha256(normalized).hexdigest(),
        "canonicalByteCount": offset,
        "architectures": [[cpu, subtype]],
        "entitlements": slots.value,
        "fullExecutableSha256": hashlib.sha256(data).hexdigest(),
        "method": "Simulator-only exact prefix bytes with three bounded signature-size fields normalized",
        "normalizedRanges": [list(item) for item in ranges],
        "signatureAllocationBytes": size,
        "signatureSuperBlobBytes": declared_length,
        "signatureAllocationPaddingBytes": len(padding),
        "signatureAllocationPaddingSha256": hashlib.sha256(padding).hexdigest(),
        "linkeditFileSize": file_size,
        "linkeditVMSize": vm_size,
    }


def find_target(module, document: dict) -> dict:
    if "TestConfigurations" in document:
        matches = [target for config in document["TestConfigurations"]
                   for target in config.get("TestTargets", [])
                   if module.target_name("", target) == module.TARGET]
    else:
        matches = [target for key, target in document.items()
                   if isinstance(target, dict)
                   and module.target_name(key, target) == module.TARGET]
    require(len(matches) == 1, "Test plan must contain one SoraPassportTests target")
    return matches[0]


def simulator_sections(executable: Path) -> dict[str, bytes]:
    data = executable.read_bytes()
    require(struct.unpack_from("<I", data)[0] == 0xFEEDFACF, "Expected thin Mach-O64")
    count = struct.unpack_from("<I", data, 16)[0]
    cursor = 32
    sections = {}
    for _ in range(count):
        command, length = struct.unpack_from("<II", data, cursor)
        if command == 0x19:
            section_count = struct.unpack_from("<I", data, cursor + 64)[0]
            require(length == 72 + 80 * section_count, "Malformed segment section table")
            for index in range(section_count):
                section = cursor + 72 + index * 80
                name = data[section:section + 16].rstrip(b"\0").decode()
                segment = data[section + 16:section + 32].rstrip(b"\0").decode()
                if segment == "__TEXT" and name in ("__entitlements", "__ents_der"):
                    size = struct.unpack_from("<Q", data, section + 40)[0]
                    offset = struct.unpack_from("<I", data, section + 48)[0]
                    require(offset + size <= len(data) and name not in sections,
                            "Invalid simulated entitlement section")
                    sections[name] = data[offset:offset + size]
        cursor += length
    return sections


def relink_simulator_host(run, projector, app: Path, signed: Path, xml: Path) -> dict:
    der = xml.with_name(xml.name + ".der")
    require(xml.is_file() and der.is_file(), "Xcode-generated XML/DER simulator entitlements are required")
    expected = {"application-identifier": EXPECTED_ENTITLEMENTS["application-identifier"]}
    require(plistlib.loads(xml.read_bytes()) == expected, "Unexpected Xcode simulated application identity")
    decoded, _ = projector.decode_der_entitlements(der.read_bytes(), "Xcode simulated DER")
    require(decoded == expected, "Xcode simulated XML/DER identities differ")
    source_log = BASE / "historical-upgrade-run-2/05-build-for-testing.log"
    matches = []
    for line in source_log.read_text().splitlines():
        if "usr/bin/clang " in line and " -o " in line:
            arguments = shlex.split(line.strip())
            if "-o" in arguments and arguments[arguments.index("-o") + 1] == str(app / "SoraPassport"):
                matches.append(arguments)
    require(len(matches) == 1, "Expected one recorded original main-app linker command")
    original_command = matches[0]
    command = list(original_command)
    original_output = command[command.index("-o") + 1]
    command[command.index("-o") + 1] = str(signed / "SoraPassport")
    redirected = {original_output: str(signed / "SoraPassport")}
    for option, name in (("-object_path_lto", "simulator-host-lto.o"),
                         ("-dependency_info", "simulator-host-dependency-info.dat")):
        indexes = [index for index, value in enumerate(command) if value == option]
        require(len(indexes) == 1 and command[indexes[0] + 1] == "-Xlinker",
                f"Unexpected recorded {option} shape")
        index = indexes[0] + 2
        redirected[command[index]] = str(run.output_root / name)
        command[index] = str(run.output_root / name)
    copied_xml = run.output_root / "Xcode-Simulated.xcent"
    copied_der = run.output_root / "Xcode-Simulated.xcent.der"
    for original, destination in ((xml, copied_xml), (der, copied_der)):
        with destination.open("xb") as stream:
            stream.write(original.read_bytes())
    require("-sectcreate" not in command, "Original linker already has explicit sections")
    for name, path in (("__entitlements", copied_xml), ("__ents_der", copied_der)):
        command.extend(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", name, "-Xlinker", str(path)])
    inputs = {}
    for index, value in enumerate(original_command):
        if value == "-filelist":
            filelist = Path(original_command[index + 1])
            inputs[str(filelist)] = digest(filelist)
            for line in filelist.read_text().splitlines():
                values = shlex.split(line)
                require(len(values) == 1, "Malformed original linker file list")
                path = Path(values[0])
                require(path.is_file(), f"Compiled linker input missing: {path}")
                inputs[str(path)] = digest(path)
        elif value.startswith("/") and Path(value).is_file() and value not in redirected:
            inputs[value] = digest(Path(value))
    require(len(inputs) > 20, "Recorded main-app object inventory is incomplete")
    record = {"method": "Relink retained compiled objects using ordinary Xcode-generated simulated entitlement sections; no source recompile or executable byte-equivalence claim",
              "originalLinkLog": str(source_log), "originalLinkLogSha256": digest(source_log),
              "originalCommand": original_command, "relinkCommand": command,
              "redirectedLinkerOutputs": redirected, "compiledInputSha256": inputs,
              "simulatedXMLSource": str(xml), "simulatedXMLSha256": digest(xml),
              "simulatedDERSource": str(der), "simulatedDERSha256": digest(der)}
    run.record["simulatorRelink"] = record
    run.save()
    run.command("relink-copied-simulator-host-from-existing-objects", command)
    require(all(Path(path).is_file() and digest(Path(path)) == value for path, value in inputs.items()),
            "Original linker inputs changed during relink")
    require(simulator_sections(signed / "SoraPassport") == {
        "__entitlements": copied_xml.read_bytes(), "__ents_der": copied_der.read_bytes()},
        "Relinked simulator sections do not match exact Xcode-generated bytes")
    record["compiledInputsUnchanged"] = True
    return record


def signed_phase(module, original: Path, phase: str, run_id: str,
                 original_app: Path, signed_app: Path) -> tuple[Path, dict]:
    path, record = module.phase_xctestrun(original, phase, run_id)
    document = plistlib.loads(path.read_bytes())
    target = find_target(module, document)
    old_host = target.get("TestHostPath")
    require(isinstance(old_host, str) and old_host.endswith(".app"),
            "Expected an application bundle TestHostPath")
    expanded_host = old_host.replace("__TESTROOT__", str(original.parent))
    require(Path(expanded_host).resolve() == original_app,
            "Original test host does not resolve to the observed built app")
    replacements = []

    def redirect(value):
        if isinstance(value, str):
            for prefix in (old_host, str(original_app)):
                if value == prefix or value.startswith(prefix + "/"):
                    changed = str(signed_app) + value[len(prefix):]
                    replacements.append({"original": value, "copy": changed})
                    return changed
        if isinstance(value, list):
            return [redirect(item) for item in value]
        if isinstance(value, dict):
            return {key: redirect(item) for key, item in value.items()}
        return value

    # Preserve every launch argument, test environment and __TESTROOT__ binding.
    # Redirect explicit references into the host copy; __TESTHOST__ follows it.
    for key in ("TestHostPath", "TestBundlePath", "DependentProductPaths",
                "EnvironmentVariables", "TestingEnvironmentVariables"):
        if key in target:
            target[key] = redirect(target[key])
    require(target["TestHostPath"] == str(signed_app), "Host redirect was not applied")
    require("-UNITTEST" in target["CommandLineArguments"], "UNITTEST argument was lost")
    bundle = target.get("TestBundlePath")
    require(isinstance(bundle, str), "Test bundle path is missing")
    resolved_bundle = bundle.replace("__TESTROOT__", str(original.parent)).replace(
        "__TESTHOST__", str(signed_app))
    require("__" not in resolved_bundle and Path(resolved_bundle).is_dir(),
            "Redirected test bundle does not exist")
    # This is our newly created plan, never the original generated test plan.
    with path.open("wb") as stream:
        plistlib.dump(document, stream, sort_keys=False)
    record.update({"copySha256": digest(path), "testHostPath": str(signed_app),
                   "hostPathReplacements": replacements})
    return path, record


def validate_failed_run(module, failed_run: Path, evidence: Path) -> dict:
    require(failed_run.is_absolute() and failed_run.resolve() == failed_run,
            "Failed-run path must be canonical and absolute")
    observation = failed_run / "run-observation.json"
    record = json.loads(observation.read_bytes())
    require(record.get("status") == "failed" and bool(record.get("finishedAt")),
            "Original rehearsal has not reached terminal failure")
    builds = [command for command in record.get("commands", [])
              if command.get("label") == "build-for-testing"]
    require(len(builds) == 1 and builds[0].get("exitCode") == 0
            and bool(builds[0].get("finishedAt")),
            "Original rehearsal build did not complete successfully")
    require(record.get("sourceAfterBuild") == record.get("sourceAtStart")
            and record.get("sourceAtStart") == module.source_snapshot(),
            "Original build source is missing, changed during build, or changed since build")
    producers = [command for command in record["commands"]
                 if command.get("label") == "produce-test-without-building"]
    require(len(producers) == 1 and producers[0].get("exitCode") not in (None, 0)
            and bool(producers[0].get("finishedAt")),
            "Original producer did not terminate with a recorded failure")
    require(evidence.is_absolute() and evidence.resolve() == evidence
            and evidence.is_relative_to(failed_run) and evidence.is_file()
            and evidence.stat().st_size <= 32 * 1024 * 1024,
            "Entitlement evidence must be a bounded retained text log inside the failed run")
    evidence_text = evidence.read_text(errors="replace")
    marker = ENTITLEMENT_FAILURE.search(evidence_text)
    require(marker is not None, "Evidence does not report a missing Keychain entitlement")
    app_record = record.get("builtApplication")
    require(isinstance(app_record, dict), "Original built-application binding is missing")
    app = Path(app_record["path"])
    require(app.resolve() == app and app.is_dir(), "Original completed app is unavailable")
    products = Path(record["derivedData"]) / "Build/Products"
    require(app.is_relative_to(products), "Observed app is outside its build Products")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require(info.get("CFBundleIdentifier") == module.BUNDLE_ID
            and info.get("CFBundleSupportedPlatforms") == ["iPhoneSimulator"],
            "Observed application is not the expected simulator app")
    executable_name = info.get("CFBundleExecutable")
    require(isinstance(executable_name, str) and Path(executable_name).name == executable_name,
            "Unexpected main executable name")
    require(digest(app / executable_name) == app_record["executableSha256"],
            "Original compiled executable changed since successful build")
    generated = [path for path in products.glob("*.xctestrun")
                 if not path.name.startswith("HistoricalWriter-")]
    require(len(generated) == 1, "Expected one original generated test plan")
    entitlements = plistlib.loads(ENTITLEMENTS.read_bytes())
    require(entitlements == EXPECTED_ENTITLEMENTS
            and type(entitlements["get-task-allow"]) is bool,
            "Existing signed entitlements no longer match the exact three-key payload")
    return {
        "failedRun": str(failed_run), "observation": str(observation),
        "observationSha256": digest(observation), "originalRunId": record["runId"],
        "entitlementEvidence": str(evidence), "entitlementEvidenceSha256": digest(evidence),
        "observedEntitlementMarker": marker.group(), "app": app,
        "executableName": executable_name, "testPlan": generated[0],
        "derivedData": Path(record["derivedData"]), "source": record["sourceAtStart"],
    }


def execute(module, projector, context: dict, output: Path, signing_identity: str,
            simulated_entitlements: Path | None = None) -> None:
    run = module.Run(output, context["derivedData"])
    run.record["scope"] = (
        "Disposable simulator historical-writer rehearsal with a signed COPY "
        "of an unchanged-source compiled test host. Signature bytes differ; compiled "
        "Mach-O code projection must match. No original App Store binary, physical-device "
        "qualification, production approval or TestFlight authorization is generated."
    )
    run.record["contingencyPreconditions"] = {
        key: str(value) if isinstance(value, Path) else value
        for key, value in context.items() if key != "source"
    }
    run.record["helperSources"] = {str(path): digest(path) for path in (RUNNER, PROJECTOR)}
    app = context["app"]
    original = context["testPlan"]
    original_plan_hash = digest(original)
    original_inventory = inventory(app)
    simulator = None
    run.save()

    def unchanged() -> None:
        require(module.source_snapshot() == context["source"], "Bound source changed")
        require(digest(original) == original_plan_hash, "Original test plan changed")
        require(inventory(app) == original_inventory, "Original application changed")

    try:
        run.command("verify-historical-provenance", [sys.executable, "-B", str(
            SOURCE / "SoraPassport/Scripts/verify-ios-historical-writer-provenance.py")])
        signed = output / "SoraPassport.app"
        shutil.copytree(app, signed, symlinks=True, copy_function=shutil.copy2)
        require(inventory(signed) == original_inventory, "App copy differs before signing")
        copied_entitlements = output / "simulator-host-entitlements.plist"
        with copied_entitlements.open("xb") as stream:
            stream.write(ENTITLEMENTS.read_bytes())
        before = projection(projector, signed / context["executableName"])
        require(before["entitlements"] in (None, {}),
                "Contingency expects an unsigned/linker-signed host without entitlements")
        run.record["signingCopy"] = {
            "original": str(app), "copy": str(signed), "before": before,
            "requestedSigningIdentity": signing_identity,
            "originalBundleInventory": original_inventory,
            "entitlementsSource": str(ENTITLEMENTS),
            "entitlementsSourceSha256": digest(ENTITLEMENTS),
            "entitlementsCopy": str(copied_entitlements),
            "entitlementsCopySha256": digest(copied_entitlements),
        }
        run.save()
        if simulated_entitlements is not None:
            relink_simulator_host(run, projector, app, signed, simulated_entitlements)
        signing_arguments = [
            "/usr/bin/codesign", "--force", "--sign", signing_identity, "--timestamp=none",
            "--generate-entitlement-der", "--identifier", module.BUNDLE_ID,
        ]
        if simulated_entitlements is None:
            signing_arguments.extend(["--entitlements", str(copied_entitlements)])
        signing_arguments.append(str(signed))
        run.command("sign-only-copied-app", signing_arguments)
        run.command("verify-copied-app-signature", [
            "/usr/bin/codesign", "--verify", "--strict", str(signed)])
        run.command("display-copied-app-signing-identity", [
            "/usr/bin/codesign", "--display", "--verbose=4", str(signed)])
        run.command("display-copied-app-entitlements", [
            "/usr/bin/codesign", "--display", "--entitlements", "-", "--xml", str(signed)])
        after = projection(projector, signed / context["executableName"])
        run.record["signingCopy"]["after"] = after
        run.save()
        if simulated_entitlements is None:
            for key in ("canonicalSha256", "canonicalByteCount", "architectures", "normalizedRanges"):
                require(after[key] == before[key], f"Signing changed compiled code: {key}")
        require(after["fullExecutableSha256"] != before["fullExecutableSha256"],
                "Expected the recorded executable signature bytes to change")
        if simulated_entitlements is None:
            require(after["entitlements"] == EXPECTED_ENTITLEMENTS,
                    "Embedded entitlements differ from the exact existing payload")
        else:
            require(after["entitlements"] in (None, {}),
                    "Ordinary simulator host must not sign restricted iOS entitlements")
            require(simulator_sections(signed / context["executableName"]) == {
                "__entitlements": (output / "Xcode-Simulated.xcent").read_bytes(),
                "__ents_der": (output / "Xcode-Simulated.xcent.der").read_bytes()},
                "Signing changed Xcode simulated entitlement sections")
            run.record["scope"] = "Disposable simulator historical-writer rehearsal using unchanged-source compiled objects, a relinked copied host with ordinary Xcode simulated entitlements, and unchanged test bundles. No original App Store binary, whole-executable byte-equivalence, physical-device qualification or production approval is claimed."
        signed_inventory = inventory(signed)
        allowed = {context["executableName"], "_CodeSignature", "_CodeSignature/CodeResources"}
        changed = [key for key in original_inventory.keys() | signed_inventory.keys()
                   if original_inventory.get(key) != signed_inventory.get(key)]
        require(set(changed) <= allowed, f"Signing changed unexpected bundle paths: {changed}")
        run.record["signingCopy"]["changedBundlePaths"] = sorted(changed)
        run.record["signingCopy"]["signedBundleInventory"] = signed_inventory
        unchanged()

        name = f"SORA Signed Historical Upgrade {run.record['runId']}"
        run.command("create-owned-simulator", ["/usr/bin/xcrun", "simctl", "create", name,
                    module.DEVICE_TYPE, module.RUNTIME])
        created = Path(run.record["commands"][-1]["log"]).read_text().strip()
        simulator = str(uuid.UUID(created)).upper()
        run.record["createdSimulator"] = {"udid": simulator, "name": name,
            "deviceType": module.DEVICE_TYPE, "runtime": module.RUNTIME}
        run.save()
        run.command("boot-owned-simulator", ["/usr/bin/xcrun", "simctl", "boot", simulator])
        run.command("wait-owned-simulator-boot", ["/usr/bin/xcrun", "simctl", "bootstatus", simulator, "-b"])
        destination = f"platform=iOS Simulator,id={simulator},arch=arm64"
        for index, phase in enumerate(module.PHASES):
            unchanged()
            require(inventory(signed) == signed_inventory, "Signed app changed between phases")
            if index:
                result = run.command(f"{phase}-terminate-host", ["/usr/bin/xcrun", "simctl", "terminate",
                    simulator, module.BUNDLE_ID], allow_failure=True)
                if result.returncode:
                    message = Path(run.record["commands"][-1]["log"]).read_text().lower()
                    require(any(text in message for text in (
                        "not running", "no such process", "found nothing to terminate")),
                        "Termination failed for a reason other than an already-stopped host")
            run.command(f"{phase}-install-same-copied-app", ["/usr/bin/xcrun", "simctl", "install", simulator, str(signed)])
            plan, phase_record = signed_phase(module, original, phase, run.record["runId"], app, signed)
            result_bundle = output / f"{phase}.xcresult"
            phase_record.update({"phase": phase, "resultBundle": str(result_bundle), "status": "running"})
            run.record["phases"].append(phase_record)
            run.save()
            run.command(f"{phase}-test-without-building", [
                "/usr/bin/xcodebuild", "test-without-building", "-xctestrun", str(plan),
                "-destination", destination, "-resultBundlePath", str(result_bundle),
                "-parallel-testing-enabled", "NO", "-maximum-concurrent-test-simulator-destinations", "1",
                f"-only-testing:{module.TARGET}/{module.TEST}",
            ])
            run.command(f"{phase}-xcresult-summary", ["/usr/bin/xcrun", "xcresulttool", "get",
                "test-results", "summary", "--path", str(result_bundle), "--compact"])
            summary = json.loads(Path(run.record["commands"][-1]["log"]).read_bytes())
            phase_record["observedXCTestSummary"] = {key: summary.get(key) for key in (
                "result", "totalTestCount", "passedTests", "failedTests", "skippedTests")}
            require(summary.get("result") == "Passed" and summary.get("totalTestCount") == 1
                    and summary.get("passedTests") == 1 and summary.get("failedTests") == 0
                    and summary.get("skippedTests") == 0,
                    f"{phase} must pass exactly one XCTest with zero failures/skips")
            phase_record["status"] = "passed"
            run.save()
        unchanged()
        run.record["sourceAtEnd"] = module.source_snapshot()
        run.record["status"] = "three-phases-passed"
    except BaseException as error:
        run.record["status"] = "failed"
        run.record["failure"] = {"type": type(error).__name__, "message": str(error)}
        if run.record["phases"] and run.record["phases"][-1]["status"] == "running":
            run.record["phases"][-1]["status"] = "failed"
        raise
    finally:
        if simulator:
            try:
                run.command("shutdown-owned-simulator", ["/usr/bin/xcrun", "simctl", "shutdown", simulator], allow_failure=True)
            except BaseException as error:
                run.record["shutdownError"] = str(error)
        run.record["finishedAt"] = module.now()
        run.record["retainedArtifacts"] = "Original build untouched; copied app, plans, logs, results and owned simulator retained. No uninstall, reset or deletion."
        run.save()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="execute only after all observed-failure preconditions pass")
    parser.add_argument("--failed-run", type=Path, help="absolute terminal rehearsal output with a successful build and failed producer")
    parser.add_argument("--entitlement-evidence", type=Path, help="absolute retained text log inside --failed-run reporting missing entitlement/-34018")
    parser.add_argument("--output-root", type=Path, help="absolute NEW owner-only output directory outside source")
    parser.add_argument("--signing-identity", choices=("-", APPLE_DEVELOPMENT_IDENTITY), default="-",
                        help="ad-hoc by default; use the fixed available Apple Development certificate if macOS rejects restricted ad-hoc entitlements")
    parser.add_argument("--xcode-simulated-entitlements", type=Path,
                        help="Xcode-generated *Simulated.xcent (and adjacent .der) for an ordinary simulator-only relink of existing objects")
    args = parser.parse_args()
    if not args.run or not all((args.failed_run, args.entitlement_evidence, args.output_root)):
        parser.error("requires --run --failed-run PATH --entitlement-evidence LOG --output-root NEW_PATH")
    module = load_module("signed_rehearsal_orchestration", RUNNER)
    projector = load_module("signed_rehearsal_projection", PROJECTOR)
    context = validate_failed_run(module, args.failed_run, args.entitlement_evidence)
    output = args.output_root
    require(output.is_absolute() and output != Path("/") and not output.exists()
            and not output.is_symlink(), "Output must be a NEW absolute non-root directory")
    require(output.parent.is_dir() and output.parent.resolve() == output.parent
            and output.parent.stat().st_uid == os.getuid(),
            "Output parent must be canonical, existing and owned by the current user")
    require(not output.is_relative_to(SOURCE) and not output.is_relative_to(context["derivedData"])
            and not output.is_relative_to(args.failed_run),
            "Output must be separate from source, original DerivedData and failed-run evidence")
    os.umask(0o077)
    output.mkdir(mode=0o700)
    execute(module, projector, context, output, args.signing_identity, args.xcode_simulated_entitlements)
    print(f"Three phases passed with the copied simulator host; inspect {output / 'run-observation.json'}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError) as error:
        print(f"Signed simulator rehearsal failed: {error}", file=sys.stderr)
        sys.exit(1)
