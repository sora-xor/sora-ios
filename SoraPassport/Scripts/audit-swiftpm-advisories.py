#!/usr/bin/env python3
"""Check immutable SwiftPM source revisions against OSV; never treat an outage as clean.

Only public dependency commit IDs leave the machine. Local source trees and binary
frameworks are outside OSV's commit coverage and still require the release review.
"""

import argparse
import datetime
import json
from pathlib import Path
import re
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
LOCKFILES = (
    "SoraPassport.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    "VendorPackages/Rswift/Package.resolved",
)


def inventory(root):
    packages = []
    for relative in LOCKFILES:
        document = json.loads((root / relative).read_text())
        pins = document.get("pins", document.get("object", {}).get("pins"))
        if not isinstance(pins, list) or not pins:
            raise ValueError(f"Missing dependency inventory: {relative}")
        for pin in pins:
            revision = pin["state"]["revision"]
            if not re.fullmatch(r"[0-9a-f]{40}", revision):
                raise ValueError(f"Non-immutable dependency revision: {relative}")
            packages.append({
                "lockfile": relative,
                "name": pin.get("identity", pin.get("package")),
                "repository": pin.get("location", pin.get("repositoryURL")),
                "version": pin["state"].get("version"),
                "revision": revision,
            })
    return packages


def post(endpoint, payload):
    request = urllib.request.Request(
        "https://api.osv.dev/v1/" + endpoint,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def scan(packages, request=post):
    response = request("querybatch", {
        "queries": [{"commit": package["revision"]} for package in packages]
    })
    if not isinstance(response, dict) or "error" in response:
        raise ValueError("OSV returned an invalid batch response")
    results = response.get("results")
    if not isinstance(results, list) or len(results) != len(packages):
        raise ValueError("OSV returned an incomplete batch")
    findings = []
    for package, result in zip(packages, results):
        seen_pages = set()
        ids = set()
        while True:
            if not isinstance(result, dict) or "error" in result:
                raise ValueError("OSV returned an invalid package result")
            vulns = result.get("vulns", [])
            if not isinstance(vulns, list):
                raise ValueError("OSV returned invalid vulnerabilities")
            for vuln in vulns:
                identifier = vuln.get("id") if isinstance(vuln, dict) else None
                if not isinstance(identifier, str) or not identifier:
                    raise ValueError("OSV returned a vulnerability without an ID")
                ids.add(identifier)
            token = result.get("next_page_token")
            if token is None or token == "":
                break
            if not isinstance(token, str) or token in seen_pages:
                raise ValueError("OSV returned invalid pagination")
            seen_pages.add(token)
            result = request("query", {"commit": package["revision"], "page_token": token})
        if ids:
            findings.append({**package, "advisories": sorted(ids)})
    return findings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Optional JSON evidence path")
    args = parser.parse_args()
    try:
        packages = inventory(ROOT)
        findings = scan(packages)
        report = {
            "checkedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "source": "https://api.osv.dev/v1/querybatch",
            "coverage": "SwiftPM source commits only; excludes vendored source and binaries",
            "packages": packages,
            "findings": findings,
        }
        if args.output:
            args.output.write_text(json.dumps(report, indent=2) + "\n")
        for finding in findings:
            print(f"{finding['name']} {finding['version']}: {', '.join(finding['advisories'])}")
        print(f"Checked {len(packages)} locked source revisions; {len(findings)} affected pins.")
        return 1 if findings else 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Dependency audit incomplete: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
