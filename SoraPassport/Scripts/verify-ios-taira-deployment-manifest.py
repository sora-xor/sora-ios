#!/usr/bin/env python3
"""Admit one externally dual-signed Taira deployment identity for iOS.

The repository deliberately contains no admitted deployment manifest.  This
tool consumes protected, owner-only runtime inputs and emits a fresh owner-only
admission receipt.  It never chooses which known UUID is current.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[2]
BLOCKED_FIXTURE = ROOT / "Fixtures/Modernization/ios-taira-deployment-manifest.blocked.json"
CONTRACT_ID = "sora-taira-deployment-manifest-v1"
ADMISSION_ID = "sora-ios-taira-deployment-admission-v1"
KNOWN_CHAIN_IDS = {
    "809574f5-fee7-5e69-bfcf-52451e42d50f",
    "fc56984b-2be7-431d-840e-21514d1883f0",
}
CONVENIENCE_HOST = "taira.sora.org"
MAX_JSON_BYTES = 128 * 1024
MAX_SIGNATURE_BYTES = 64 * 1024
MAX_KEY_BYTES = 64 * 1024
MAX_AGE_SECONDS = 7 * 24 * 60 * 60
MAX_FUTURE_SKEW_SECONDS = 60
MAX_VALIDITY_SECONDS = 30 * 24 * 60 * 60
MAX_SAFE_INTEGER = 9_007_199_254_740_991
HEX64 = re.compile(r"^[0-9a-f]{64}$")
KEY_ID = re.compile(r"^[a-z0-9][a-z0-9._:-]{2,127}$")
MANIFEST_ID = re.compile(r"^[a-z0-9][a-z0-9._:-]{2,127}$")
DNS_NAME = re.compile(
    r"^(?=.{4,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+"
    r"[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$"
)
SAFE_ENV = {"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"}


class AdmissionError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise AdmissionError(message)


def canonical_json(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8") + b"\n"


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, child in pairs:
        if key in value:
            fail(f"duplicate JSON key after escape decoding: {key}")
        value[key] = child
    return value


def reject_float(value: str) -> Any:
    fail(f"floating-point JSON is forbidden: {value}")


def reject_constant(value: str) -> Any:
    fail(f"non-finite JSON is forbidden: {value}")


def parse_integer(value: str) -> int:
    if value == "-0":
        fail("negative-zero JSON is forbidden")
    parsed = int(value)
    if abs(parsed) > MAX_SAFE_INTEGER:
        fail("JSON integer exceeds the exact safe range")
    return parsed


def exact(value: Any, keys: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != keys:
        fail(f"{label} has a stale, mixed, or incomplete shape")
    return value


def text(value: Any, label: str, maximum: int = 512) -> str:
    if (
        type(value) is not str
        or not value
        or len(value) > maximum
        or any(ord(character) < 0x20 or 0x7F <= ord(character) <= 0x9F for character in value)
    ):
        fail(f"{label} must be one bounded printable string")
    return value


def digest(value: Any, label: str) -> str:
    candidate = text(value, label, 64)
    if HEX64.fullmatch(candidate) is None or candidate == "0" * 64:
        fail(f"{label} must be one nonzero lowercase SHA-256")
    return candidate


def positive_integer(value: Any, label: str) -> int:
    if type(value) is not int or not 1 <= value <= MAX_SAFE_INTEGER:
        fail(f"{label} must be one positive exact integer")
    return value


def absolute_path(raw: str, label: str) -> Path:
    path = Path(raw)
    if not path.is_absolute() or str(path) != raw or raw == "/" or len(raw) > 4096:
        fail(f"{label} must be one canonical absolute path")
    if any(component in ("", ".", "..") for component in path.parts[1:]):
        fail(f"{label} contains an unsafe path component")
    try:
        parent = path.parent.resolve(strict=True)
    except (OSError, RuntimeError) as error:
        fail(f"{label} parent is unavailable: {error}")
    if parent != path.parent:
        fail(f"{label} traverses a symbolic or noncanonical parent")
    return path


def protected_file(path: Path, maximum: int, label: str) -> tuple[bytes, os.stat_result]:
    if not hasattr(os, "O_NOFOLLOW"):
        fail("platform cannot reject symbolic-link inputs")
    flags = os.O_RDONLY | os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} cannot be opened without aliases: {error}")
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or before.st_uid != os.getuid()
            or stat.S_IMODE(before.st_mode) != 0o600
            or before.st_size <= 0
            or before.st_size > maximum
        ):
            fail(f"{label} is not one bounded owner-only, hardlink-free regular inode")
        chunks: list[bytes] = []
        observed = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - observed))
            if not chunk:
                break
            observed += len(chunk)
            if observed > maximum:
                fail(f"{label} exceeds its byte bound")
            chunks.append(chunk)
        after = os.fstat(descriptor)
        named = os.stat(path, follow_symlinks=False)
        identity = lambda item: (
            item.st_dev, item.st_ino, item.st_mode, item.st_nlink,
            item.st_size, item.st_mtime_ns, item.st_ctime_ns,
        )
        if observed != before.st_size or identity(before) != identity(after) or identity(before) != identity(named):
            fail(f"{label} changed or was rebound while read")
        return b"".join(chunks), before
    finally:
        os.close(descriptor)


def parse_canonical(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            raw.decode("utf-8", "strict"),
            object_pairs_hook=strict_object,
            parse_int=parse_integer,
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, AdmissionError) as error:
        fail(f"{label} is invalid strict JSON: {error}")
    if type(value) is not dict or canonical_json(value) != raw:
        fail(f"{label} is not canonical JSON")
    return value


def canonical_public_base(value: Any, label: str) -> str:
    candidate = text(value, label, 2048)
    parts = urlsplit(candidate)
    host = parts.hostname
    if (
        parts.scheme != "https"
        or host is None
        or host != host.lower()
        or host == CONVENIENCE_HOST
        or DNS_NAME.fullmatch(host) is None
        or parts.username is not None
        or parts.password is not None
        or parts.port not in (None, 443)
        or parts.path not in ("", "/")
        or parts.query
        or parts.fragment
        or candidate.endswith("/")
    ):
        fail(f"{label} must be one canonical explicit public HTTPS origin and must not use {CONVENIENCE_HOST}")
    expected = f"https://{host}" + (":443" if parts.port == 443 else "")
    if candidate != expected:
        fail(f"{label} is not in canonical origin form")
    return candidate


def validate_epoch(value: Any, label: str) -> dict[str, Any]:
    epoch = exact(
        value,
        {"chainId", "role", "deploymentEpoch", "genesisHash", "canonicalToriiBaseUrl", "publicMcpEndpoint"},
        label,
    )
    chain_id = text(epoch["chainId"], f"{label}.chainId", 36)
    if chain_id not in KNOWN_CHAIN_IDS:
        fail(f"{label}.chainId is not one of the two known UUIDs")
    role = text(epoch["role"], f"{label}.role", 16)
    if role not in ("current", "retired"):
        fail(f"{label}.role must be current or retired")
    positive_integer(epoch["deploymentEpoch"], f"{label}.deploymentEpoch")
    digest(epoch["genesisHash"], f"{label}.genesisHash")
    if role == "current":
        base = canonical_public_base(epoch["canonicalToriiBaseUrl"], f"{label}.canonicalToriiBaseUrl")
        endpoint = text(epoch["publicMcpEndpoint"], f"{label}.publicMcpEndpoint", 2060)
        if endpoint != f"{base}/v1/mcp":
            fail(f"{label}.publicMcpEndpoint must be the explicit canonical /v1/mcp route")
    elif epoch["canonicalToriiBaseUrl"] is not None or epoch["publicMcpEndpoint"] is not None:
        fail(f"{label} retired identity must not authorize transport")
    return epoch


def validate_manifest(value: Any, evaluated_at: int) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest = exact(
        value,
        {
            "schemaVersion", "contractId", "manifestId", "issuedAtEpochSeconds",
            "expiresAtEpochSeconds", "authorities", "pendingRowPolicy", "epochs",
        },
        "deployment manifest",
    )
    if manifest["schemaVersion"] != 1 or manifest["contractId"] != CONTRACT_ID:
        fail("deployment manifest is an obsolete or unknown contract")
    manifest_id = text(manifest["manifestId"], "manifestId", 128)
    if MANIFEST_ID.fullmatch(manifest_id) is None:
        fail("manifestId is not canonical")
    issued = positive_integer(manifest["issuedAtEpochSeconds"], "issuedAtEpochSeconds")
    expires = positive_integer(manifest["expiresAtEpochSeconds"], "expiresAtEpochSeconds")
    if expires <= issued or expires - issued > MAX_VALIDITY_SECONDS:
        fail("manifest validity interval is empty or exceeds its bound")
    if evaluated_at + MAX_FUTURE_SKEW_SECONDS < issued:
        fail("manifest was issued too far in the future")
    if evaluated_at > expires or evaluated_at - issued > MAX_AGE_SECONDS:
        fail("manifest is expired or older than seven days")
    authorities = exact(manifest["authorities"], {"operatorKeyId", "reviewerKeyId"}, "authorities")
    operator_id = text(authorities["operatorKeyId"], "operatorKeyId", 128)
    reviewer_id = text(authorities["reviewerKeyId"], "reviewerKeyId", 128)
    if KEY_ID.fullmatch(operator_id) is None or KEY_ID.fullmatch(reviewer_id) is None or operator_id == reviewer_id:
        fail("operator and reviewer key IDs must be distinct canonical identifiers")
    policy = exact(
        manifest["pendingRowPolicy"],
        {"schemaVersion", "preserveExactChainUuid", "mismatchedCurrentDisposition", "reinterpretationAllowed"},
        "pendingRowPolicy",
    )
    if (
        policy["schemaVersion"] != 77
        or policy["preserveExactChainUuid"] is not True
        or policy["mismatchedCurrentDisposition"] != "quarantine-recovery-only"
        or policy["reinterpretationAllowed"] is not False
    ):
        fail("schema-77 pending rows must preserve UUID and quarantine non-current rows without reinterpretation")
    epochs = manifest["epochs"]
    if type(epochs) is not list or len(epochs) != 2:
        fail("manifest must contain exactly two deployment epoch records")
    parsed = [validate_epoch(item, f"epochs[{index}]") for index, item in enumerate(epochs)]
    if {item["chainId"] for item in parsed} != KNOWN_CHAIN_IDS or {item["role"] for item in parsed} != {"current", "retired"}:
        fail("manifest must map both known UUIDs to distinct current and retired roles")
    if len({item["deploymentEpoch"] for item in parsed}) != 2 or len({item["genesisHash"] for item in parsed}) != 2:
        fail("deployment epochs and genesis hashes must be distinct and nonzero")
    current = next(item for item in parsed if item["role"] == "current")
    retired = next(item for item in parsed if item["role"] == "retired")
    if current["deploymentEpoch"] <= retired["deploymentEpoch"]:
        fail("current deployment epoch must be newer than the retired epoch")
    return current, retired


def run_openssl(arguments: list[str], label: str) -> bytes:
    result = subprocess.run(
        ["/usr/bin/openssl", *arguments],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_ENV,
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        fail(f"{label} failed")
    return result.stdout


def validate_public_key(path: Path, raw: bytes, expected_sha: str, label: str) -> None:
    if sha256(raw) != digest(expected_sha, f"{label} protected pin"):
        fail(f"{label} public key differs from its protected SHA-256 pin")
    details = run_openssl(["pkey", "-pubin", "-in", str(path), "-text_pub", "-noout"], f"{label} public-key inspection")
    if b"ASN1 OID: prime256v1" not in details and b"NIST CURVE: P-256" not in details:
        fail(f"{label} public key is not ECDSA P-256")


def verify_signature(manifest: Path, signature: Path, key: Path, label: str) -> None:
    run_openssl(
        ["dgst", "-sha256", "-verify", str(key), "-signature", str(signature), str(manifest)],
        f"{label} detached signature verification",
    )


def publish(path: Path, value: dict[str, Any]) -> None:
    parent = os.stat(path.parent, follow_symlinks=False)
    if not stat.S_ISDIR(parent.st_mode) or parent.st_uid != os.getuid() or stat.S_IMODE(parent.st_mode) != 0o700:
        fail("admission output parent must be current-user-owned mode 0700")
    if path.exists() or path.is_symlink():
        fail("admission output must be fresh")
    raw = canonical_json(value)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags, 0o600)
    completed = False
    try:
        written = os.write(descriptor, raw)
        if written != len(raw):
            fail("admission output was only partially written")
        os.fsync(descriptor)
        metadata = os.fstat(descriptor)
        if metadata.st_nlink != 1 or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o600:
            fail("admission output lost its owner-only identity")
        completed = True
    finally:
        os.close(descriptor)
        if not completed:
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass


def verify_protected(arguments: list[str]) -> dict[str, Any]:
    names = (
        "--manifest", "--operator-signature", "--reviewer-signature",
        "--operator-public-key", "--reviewer-public-key", "--operator-key-sha256",
        "--reviewer-key-sha256", "--evaluated-at-epoch-seconds", "--output",
    )
    if len(arguments) != len(names) * 2 or tuple(arguments[::2]) != names:
        fail("protected verification arguments are not exact")
    values = dict(zip(names, arguments[1::2]))
    evaluated_raw = values["--evaluated-at-epoch-seconds"]
    if not evaluated_raw.isdigit() or evaluated_raw.startswith("0"):
        fail("evaluation epoch must be one canonical positive integer")
    evaluated_at = positive_integer(int(evaluated_raw), "evaluation epoch")
    manifest_path = absolute_path(values["--manifest"], "manifest")
    operator_signature_path = absolute_path(values["--operator-signature"], "operator signature")
    reviewer_signature_path = absolute_path(values["--reviewer-signature"], "reviewer signature")
    operator_key_path = absolute_path(values["--operator-public-key"], "operator public key")
    reviewer_key_path = absolute_path(values["--reviewer-public-key"], "reviewer public key")
    output_path = absolute_path(values["--output"], "admission output")
    paths = [manifest_path, operator_signature_path, reviewer_signature_path, operator_key_path, reviewer_key_path]
    if len(set(paths)) != len(paths) or output_path in paths:
        fail("protected manifest, signatures, keys, and output paths must be distinct")
    manifest_raw, manifest_identity = protected_file(manifest_path, MAX_JSON_BYTES, "manifest")
    operator_signature_raw, _ = protected_file(operator_signature_path, MAX_SIGNATURE_BYTES, "operator signature")
    reviewer_signature_raw, _ = protected_file(reviewer_signature_path, MAX_SIGNATURE_BYTES, "reviewer signature")
    operator_key_raw, _ = protected_file(operator_key_path, MAX_KEY_BYTES, "operator public key")
    reviewer_key_raw, _ = protected_file(reviewer_key_path, MAX_KEY_BYTES, "reviewer public key")
    if operator_signature_raw == reviewer_signature_raw or operator_key_raw == reviewer_key_raw:
        fail("operator and reviewer signature/key identities must be distinct")
    manifest = parse_canonical(manifest_raw, "deployment manifest")
    current, retired = validate_manifest(manifest, evaluated_at)
    validate_public_key(operator_key_path, operator_key_raw, values["--operator-key-sha256"], "operator")
    validate_public_key(reviewer_key_path, reviewer_key_raw, values["--reviewer-key-sha256"], "reviewer")
    verify_signature(manifest_path, operator_signature_path, operator_key_path, "operator")
    verify_signature(manifest_path, reviewer_signature_path, reviewer_key_path, "reviewer")
    named = os.stat(manifest_path, follow_symlinks=False)
    if (named.st_dev, named.st_ino, named.st_size, named.st_mtime_ns) != (
        manifest_identity.st_dev, manifest_identity.st_ino, manifest_identity.st_size, manifest_identity.st_mtime_ns
    ):
        fail("manifest changed after signature verification")
    admission = {
        "schemaVersion": 1,
        "contractId": ADMISSION_ID,
        "status": "admitted",
        "evaluatedAtEpochSeconds": evaluated_at,
        "manifestSha256": sha256(manifest_raw),
        "operatorSignatureSha256": sha256(operator_signature_raw),
        "reviewerSignatureSha256": sha256(reviewer_signature_raw),
        "operatorPublicKeySpkiSha256": sha256(operator_key_raw),
        "reviewerPublicKeySpkiSha256": sha256(reviewer_key_raw),
        "current": current,
        "retired": retired,
        "pendingRowPolicy": manifest["pendingRowPolicy"],
    }
    publish(output_path, admission)
    return admission


def lint_contract() -> None:
    raw = BLOCKED_FIXTURE.read_bytes()
    blocked = parse_canonical(raw, "blocked deployment fixture")
    exact(blocked, {"schemaVersion", "contractId", "status", "blockers", "admittedManifest"}, "blocked deployment fixture")
    if (
        blocked["schemaVersion"] != 1
        or blocked["contractId"] != "sora-ios-taira-deployment-manifest-blocked-v1"
        or blocked["status"] != "blocked"
        or blocked["admittedManifest"] is not None
        or type(blocked["blockers"]) is not list
        or len(blocked["blockers"]) < 1
        or any(type(item) is not str or not item for item in blocked["blockers"])
    ):
        fail("blocked deployment fixture could be mistaken for admission")


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-contract"]:
            lint_contract()
            print("iOS Taira deployment manifest contract: OK (blocked; no admitted manifest)")
            return 0
        if argv and argv[0] == "--verify-protected":
            admission = verify_protected(argv[1:])
            print(
                f"manifestSha256={admission['manifestSha256']} "
                f"admissionSha256={sha256(canonical_json(admission))} "
                f"currentChainId={admission['current']['chainId']} "
                f"currentGenesisHash={admission['current']['genesisHash']} "
                f"currentDeploymentEpoch={admission['current']['deploymentEpoch']} "
                f"currentToriiBaseUrl={admission['current']['canonicalToriiBaseUrl']} "
                f"currentMcpEndpoint={admission['current']['publicMcpEndpoint']} "
                f"retiredChainId={admission['retired']['chainId']}"
            )
            return 0
        fail("usage: verify-ios-taira-deployment-manifest.py --lint-contract | --verify-protected ...")
    except (AdmissionError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
