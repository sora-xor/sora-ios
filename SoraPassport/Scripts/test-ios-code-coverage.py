#!/usr/bin/env python3
"""Regression tests for the production coverage denominator and fail-closed gate."""
import importlib.util
from pathlib import Path
import unittest
import tempfile

spec = importlib.util.spec_from_file_location("coverage_gate", Path(__file__).with_name("check-ios-code-coverage.py"))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class CoverageScopeTests(unittest.TestCase):
    @staticmethod
    def report(files):
        return {"targets": [{"name": "SoraPassport.app", "files": files,
                             "coveredLines": sum(f["coveredLines"] for f in files),
                             "executableLines": sum(f["executableLines"] for f in files)}]}

    @staticmethod
    def source(path, hits, lines):
        return {"path": "/checkout/sora-ios/" + path, "coveredLines": hits, "executableLines": lines}

    def test_source_manifest_includes_first_party_codec_and_detects_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            app = repo / "SoraPassport/Screen.swift"
            codec = repo / gate.CODEC_ROOT / "Codec.swift"
            dependency = repo / "VendorPackages/Dependency/Source.swift"
            for path in [app, codec, dependency]:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("original")
            before = gate.source_manifest(repo)
            self.assertEqual(set(before), {str(app.relative_to(repo)), str(codec.relative_to(repo))})
            codec.write_text("changed")
            self.assertNotEqual(before, gate.source_manifest(repo))

    def test_unexecuted_ui_and_debug_production_remain_in_denominator(self):
        report = self.report([
            self.source("SoraPassport/Common/Service.swift", 10, 10),
            self.source("SoraPassport/ModulesRedesign/Screen.swift", 0, 50),
            self.source("SoraPassport/Common/MigrationEvidence/Harness.swift", 0, 40),
        ])
        files = gate.app_files(report)
        self.assertEqual(sum(v[0] for v in files.values()), 10)
        self.assertEqual(sum(v[1] for v in files.values()), 100)

    def test_only_named_generated_output_is_excluded(self):
        report = self.report([
            self.source("R.generated.swift", 0, 100),
            self.source("SoraPassport/Common/GeneratedLookingProduction.swift", 0, 20),
            self.source("SoraPassport/Common/Service.swift", 8, 10),
        ])
        self.assertEqual(gate.app_files(report), {
            "SoraPassport/Common/GeneratedLookingProduction.swift": (0, 20),
            "SoraPassport/Common/Service.swift": (8, 10),
        })

    def test_missing_and_empty_app_coverage_fail(self):
        for report in [{}, {"targets": []}, self.report([])]:
            with self.assertRaises(ValueError):
                gate.app_files(report)

    def test_filtered_file_totals_fail(self):
        report = self.report([self.source("SoraPassport/UI.swift", 0, 20)])
        report["targets"][0]["executableLines"] = 100
        with self.assertRaises(ValueError):
            gate.app_files(report)

    def test_duplicate_sources_and_noninteger_counts_fail(self):
        file = self.source("SoraPassport/UI.swift", 0, 20)
        for report in [self.report([file, file]), self.report([self.source("SoraPassport/UI.swift", 1.5, 20)])]:
            with self.assertRaises(ValueError):
                gate.app_files(report)

    def test_dependency_target_cannot_raise_app_coverage(self):
        report = self.report([self.source("SoraPassport/UI.swift", 0, 20)])
        report["targets"].append({"name": "Dependency", "coveredLines": 1000, "executableLines": 1000})
        self.assertEqual(gate.app_files(report), {"SoraPassport/UI.swift": (0, 20)})

    def test_first_party_codec_cannot_be_omitted(self):
        repo = Path(__file__).resolve().parents[2]
        with self.assertRaises(ValueError):
            gate.codec_files({"data": [{"files": []}]}, repo)

    def test_raw_lines_count_overlapping_function_ranges_once(self):
        path = "SoraPassport/UI.swift"
        archive = {"/checkout/sora-ios/" + path: [
            {"line": 1, "isExecutable": False},
            {"line": 2, "isExecutable": True, "executionCount": 5},
            {"line": 3, "isExecutable": True, "executionCount": 0},
        ]}
        self.assertEqual(gate.source_line_files({path: (10, 20)}, archive), {path: {2: True, 3: False}})

    def test_raw_source_omissions_fail_instead_of_shrinking_denominator(self):
        with self.assertRaises(ValueError):
            gate.source_line_files({"SoraPassport/UI.swift": (0, 20)}, {})

    def test_raw_duplicate_line_is_rejected(self):
        line = {"line": 2, "isExecutable": True, "executionCount": 1}
        with self.assertRaises(ValueError):
            gate.source_line_files({"SoraPassport/UI.swift": (1, 1)},
                                  {"/checkout/sora-ios/SoraPassport/UI.swift": [line, line]})

    def test_merge_unions_hits_and_keeps_uncovered_files(self):
        first = {"a": {1: True, 2: False}, "ui": {7: False}}
        second = {"a": {1: False, 2: True}, "ui": {7: False}}
        manifest = {"a": "sha-a", "ui": "sha-ui"}
        self.assertEqual(gate.merge_source_lines([first, second], [manifest, manifest]),
                         {"a": {1: True, 2: True}, "ui": {7: False}})
        self.assertFalse(first["a"][2], "Merging must not rewrite input evidence")

    def test_merge_rejects_changed_sources_even_when_line_numbers_match(self):
        coverage = {"a": {1: True}}
        with self.assertRaises(ValueError):
            gate.merge_source_lines([coverage, coverage], [{"a": "old"}, {"a": "new"}])

    def test_merge_rejects_missing_manifests_changed_files_and_changed_line_sets(self):
        coverage = {"a": {1: True}, "ui": {7: False}}
        manifest = {"a": "sha-a", "ui": "sha-ui"}
        for incoming, manifests in [
            (coverage, []),
            ({"a": {1: True}}, [manifest, manifest]),
            ({"a": {1: True}, "ui": {8: False}}, [manifest, manifest]),
        ]:
            with self.assertRaises(ValueError):
                gate.merge_source_lines([coverage, incoming], manifests)


if __name__ == "__main__":
    unittest.main()
