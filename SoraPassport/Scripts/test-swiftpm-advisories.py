#!/usr/bin/env python3
"""Regression tests for advisory scan coverage and fail-closed responses."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "audit", Path(__file__).with_name("audit-swiftpm-advisories.py")
)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AdvisoryTests(unittest.TestCase):
    packages = [{"name": "example", "version": "1.0.0", "revision": "a" * 40}]

    def test_empty_result_is_clean(self):
        self.assertEqual(audit.scan(self.packages, lambda *_: {"results": [{}]}), [])

    def test_incomplete_batch_fails(self):
        for response in ([], {}, {"results": []}, {"results": {}},
                         {"error": "unavailable", "results": [{}]}):
            with self.subTest(response=response), self.assertRaises(ValueError):
                audit.scan(self.packages, lambda *_: response)

    def test_error_result_fails(self):
        with self.assertRaises(ValueError):
            audit.scan(self.packages, lambda *_: {"results": [{"error": "unavailable"}]})

    def test_invalid_advisory_fails(self):
        with self.assertRaises(ValueError):
            audit.scan(self.packages, lambda *_: {"results": [{"vulns": [{}]}]})

    def test_pagination_keeps_all_advisories(self):
        def request(endpoint, payload):
            if endpoint == "querybatch":
                return {"results": [{"vulns": [{"id": "A"}], "next_page_token": "page2"}]}
            self.assertEqual(payload, {"commit": "a" * 40, "page_token": "page2"})
            return {"vulns": [{"id": "B"}, {"id": "A"}]}
        self.assertEqual(audit.scan(self.packages, request)[0]["advisories"], ["A", "B"])

    def test_pagination_loop_fails(self):
        page = {"next_page_token": "again"}
        with self.assertRaises(ValueError):
            audit.scan(self.packages, lambda endpoint, _: {"results": [page]} if endpoint == "querybatch" else page)
        for token in (False, 0, [], {}):
            with self.subTest(token=token), self.assertRaises(ValueError):
                audit.scan(self.packages, lambda *_: {"results": [{"next_page_token": token}]})


if __name__ == "__main__":
    unittest.main()
