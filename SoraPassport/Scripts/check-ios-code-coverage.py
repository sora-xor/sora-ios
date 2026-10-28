#!/usr/bin/env python3
"""Gate first-party production line coverage from Xcode and SwiftPM reports.

The Xcode report must come from the complete SoraPassport app target, including
unexecuted UI, migration and debug-only app code. Only R.swift's generated output
is removed. NexusTransferCodec is app-owned, despite its VendorPackages location,
and its llvm-cov report is included. Third-party dependency/test targets are not.
"""

import argparse
import json
import hashlib
from pathlib import Path
import sys

APP_TARGET = "SoraPassport.app"
APP_ROOT = "SoraPassport/"
CODEC_ROOT = "VendorPackages/NexusTransferCodec/Sources/NexusTransferCodec/"
GENERATED = {"R.generated.swift"}


def relative_source(path, prefix):
    marker = "/" + prefix
    normalized = str(path).replace("\\", "/")
    if normalized.startswith(prefix):
        return normalized
    if marker not in normalized:
        raise ValueError(f"unexpected production source outside {prefix}: {path}")
    return prefix + normalized.rsplit(marker, 1)[1]


def counts(covered, executable, path):
    if (type(covered) is not int or type(executable) is not int
            or not 0 <= covered <= executable):
        raise ValueError(f"invalid line counts for {path}")
    return covered, executable


def app_files(report):
    targets = [target for target in report.get("targets", []) if target.get("name") == APP_TARGET]
    if len(targets) != 1 or not targets[0].get("files"):
        raise ValueError("missing complete SoraPassport.app coverage; test-without-building may omit metadata")
    files = {}
    all_covered = all_executable = 0
    for source in targets[0]["files"]:
        path = ("R.generated.swift" if Path(source["path"]).name == "R.generated.swift"
                else relative_source(source["path"], APP_ROOT))
        value = counts(source["coveredLines"], source["executableLines"], path)
        if path in files:
            raise ValueError(f"duplicate app source: {path}")
        all_covered += value[0]
        all_executable += value[1]
        files[path] = value
    if (all_covered, all_executable) != counts(targets[0]["coveredLines"], targets[0]["executableLines"], APP_TARGET):
        raise ValueError("app file totals differ from target totals; report may have been filtered")
    return {path: value for path, value in files.items() if path not in GENERATED}



def source_manifest(repo):
    paths = (list((repo / APP_ROOT).rglob("*.swift"))
             + list((repo / CODEC_ROOT).rglob("*.swift"))
             + [repo / "R.generated.swift"])
    return {str(path.relative_to(repo)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(paths) if path.is_file()}


def source_line_files(report_files, archive):
    """Count each source line once, including zero-hit production files."""
    files = {}
    for absolute, entries in archive.items():
        if Path(absolute).name == "R.generated.swift":
            continue
        path = relative_source(absolute, APP_ROOT)
        if path not in report_files:
            raise ValueError(f"archive source missing from complete app report: {path}")
        if path in files:
            raise ValueError(f"duplicate archive source: {path}")
        lines = {}
        seen = set()
        for entry in entries:
            number = entry["line"]
            if type(number) is not int or number <= 0 or number in seen:
                raise ValueError(f"invalid or duplicate source line: {path}:{number}")
            seen.add(number)
            if entry.get("isExecutable"):
                hits = entry.get("executionCount")
                if type(hits) is not int or hits < 0:
                    raise ValueError(f"invalid execution count: {path}:{number}")
                lines[number] = hits > 0
        files[path] = lines
    if set(files) != set(report_files):
        raise ValueError(f"incomplete raw source coverage: {sorted(set(report_files) - set(files))}")
    return files


def merge_source_lines(inputs, manifests):
    if not inputs:
        raise ValueError("no raw source coverage")
    if len(inputs) > 1 and (len(manifests) != len(inputs) or not manifests[0]):
        raise ValueError("merging requires a source manifest captured for every test build")
    merged = {path: dict(lines) for path, lines in inputs[0].items()}
    for index, incoming in enumerate(inputs[1:], 1):
        if manifests[index] != manifests[0]:
            raise ValueError("cannot merge coverage from changed source files")
        if incoming.keys() != merged.keys():
            raise ValueError("cannot merge coverage with different production files")
        for path, lines in incoming.items():
            if lines.keys() != merged[path].keys():
                raise ValueError(f"cannot merge changed executable source lines: {path}")
            if path not in manifests[index]:
                raise ValueError(f"source manifest omits production file: {path}")
            merged[path] = {number: hit or merged[path][number] for number, hit in lines.items()}
    return merged


def codec_files(report, repo):
    files = {}
    for unit in report.get("data", []):
        for source in unit.get("files", []):
            # llvm-cov also reports test sources; the complete first-party library
            # is the production component, regardless of whether tests import it.
            if "/" + CODEC_ROOT not in source["filename"]:
                continue
            path = relative_source(source["filename"], CODEC_ROOT)
            summary = source["summary"]["lines"]
            if path in files:
                raise ValueError(f"duplicate codec source: {path}")
            files[path] = counts(summary["covered"], summary["count"], path)
    expected = {str(path.relative_to(repo)) for path in (repo / CODEC_ROOT).rglob("*.swift")}
    if not files or set(files) != expected:
        raise ValueError(f"incomplete codec source coverage; missing {sorted(expected - set(files))}")
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-report", type=Path, help="xccov view --report --json output")
    parser.add_argument("--app-archive", type=Path, action="append", default=[], help="xccov view --archive --json output")
    parser.add_argument("--app-manifest", type=Path, action="append", default=[], help="source hashes captured before each test build; required when merging")
    parser.add_argument("--write-source-manifest", type=Path, help="capture source hashes before building, then exit")
    parser.add_argument("--codec-report", type=Path, help="SwiftPM llvm-cov JSON output")
    parser.add_argument("--minimum", type=float, default=80)
    parser.add_argument("--output", type=Path, help="write auditable per-file summary JSON")
    args = parser.parse_args()
    if not 0 <= args.minimum <= 100:
        parser.error("minimum must be between 0 and 100")
    repo = Path(__file__).resolve().parents[2]
    if args.write_source_manifest:
        args.write_source_manifest.write_text(json.dumps(source_manifest(repo), indent=2) + "\n")
        return 0
    if not args.app_report or not args.app_archive or not args.codec_report:
        parser.error("app-report, app-archive and codec-report are required")
    try:
        ranges = app_files(json.loads(args.app_report.read_text()))
        raw = [source_line_files(ranges, json.loads(path.read_text())) for path in args.app_archive]
        manifests = [json.loads(path.read_text()) for path in args.app_manifest]
        lines = merge_source_lines(raw, manifests)
        app = {path: (sum(values.values()), len(values)) for path, values in lines.items()}
        codec = codec_files(json.loads(args.codec_report.read_text()), repo)
        files = app | codec
        covered = sum(value[0] for value in files.values())
        executable = sum(value[1] for value in files.values())
        if executable == 0:
            raise ValueError("coverage denominator is empty")
        percent = covered / executable * 100
        summary = {
            "scope": "unique executable source lines in all app-owned production, including UI and debug code; generated R.swift excluded",
            "xcodeFunctionRangeTotals": {"coveredLines": sum(x[0] for x in ranges.values()),
                                         "executableLines": sum(x[1] for x in ranges.values())},
            "excludedGeneratedFiles": sorted(GENERATED),
            "coveredLines": covered, "executableLines": executable, "lineCoveragePercent": percent,
            "minimumPercent": args.minimum, "passed": covered * 100 >= executable * args.minimum,
            "components": {name: {"coveredLines": sum(x[0] for x in component.values()),
                                    "executableLines": sum(x[1] for x in component.values()),
                                    "sourceFiles": len(component)}
                           for name, component in [(APP_TARGET, app), ("NexusTransferCodec", codec)]},
            "files": [{"path": path, "coveredLines": value[0], "executableLines": value[1]}
                      for path, value in sorted(files.items())],
        }
        if args.output:
            args.output.write_text(json.dumps(summary, indent=2) + "\n")
        print(f"iOS production line coverage: {covered:,}/{executable:,} = {percent:.2f}% (required {args.minimum:g}%)")
        return 0 if summary["passed"] else 1
    except (KeyError, TypeError, ValueError, OSError) as error:
        print(f"coverage error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
