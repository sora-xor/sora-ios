#!/usr/bin/env python3
"""Exercise the shipped Foundation manager and Egyptian packaging in isolation.

Compiles the actual app extension, language model, settings implementation, and
vendored localization manager. Only the app's SettingsKey enum is extracted to
avoid compiling unrelated wallet code. No application or wallet store is opened.
"""

from __future__ import annotations

import importlib.util
import contextlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "SoraPassport"
EXTENSION = APP / "Common/Extensions/LocalizationManager+Shared.swift"


class EgyptianLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="sora-egyptian-localization-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.build = Path(cls.temporary.name)
        settings = ROOT / "VendorPackages/shared-features-spm/Sources/SoraKeystore/Classes/UserDefaults"
        cls.compile("-emit-library", "-emit-module", "-module-name", "SoraKeystore",
                    *sorted(settings.glob("*.swift")), "-o", cls.build / "libSoraKeystore.dylib")
        cls.compile("-emit-library", "-emit-module", "-module-name", "SoraFoundation",
                    ROOT / "VendorPackages/SoraFoundation/SoraFoundation/Classes/Localization/LocalizationManager.swift",
                    "-I", cls.build, "-L", cls.build, "-lSoraKeystore",
                    "-o", cls.build / "libSoraFoundation.dylib")
        settings_source = (APP / "Common/Extensions/SettingsExtension.swift").read_text()
        declaration = re.search(r"enum SettingsKey: String \{[^}]+\}", settings_source)
        if declaration is None:
            raise AssertionError("SettingsKey declaration was not found")
        (cls.build / "SettingsKey.swift").write_text(declaration.group() + "\n")
        (cls.build / "main.swift").write_text(r'''
import Foundation
import SoraFoundation
import SoraKeystore

let mode = CommandLine.arguments[1]
let settings = InMemorySettingsManager()
let key = SettingsKey.selectedLocalization.rawValue
let originalData = Data([7, 4, 1])
settings.set(value: originalData, for: "retained-setting")
let code = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "egy-Egyp"
if mode != "fresh" { settings.set(value: code, for: key) }
let available = mode == "unavailable" ? ["en"] : ["en", "egy", "akk", "ja", "ar"]
let manager = LocalizationManager(settings: settings, key: key,
    preferredLanguages: [code], availableLocalizations: available)
let observer = NSObject()
var notifications = 0
manager.addObserver(with: observer) { _, _ in notifications += 1 }
precondition(manager.preservingLegacyEgyptianSelection() === manager)
let expected = mode == "unavailable" ? code : (code == "egy-Egyp" ? "egy" : code)
precondition(manager.selectedLocalization == expected)
precondition(manager.selectedLanguage.code == expected)
precondition(manager.preferredLocalizations == [expected])
precondition(settings.string(for: key) == expected)
precondition(settings.data(for: "retained-setting") == originalData)
precondition(Set(settings.allKeys()) == Set([key, "retained-setting"]))
precondition(notifications == (mode != "fresh" && code == "egy-Egyp" && mode != "unavailable" ? 1 : 0))
manager.preservingLegacyEgyptianSelection()
let restarted = LocalizationManager(settings: settings, key: key,
    preferredLanguages: ["en"], availableLocalizations: available)
    .preservingLegacyEgyptianSelection()
precondition(restarted.selectedLocalization == expected)
precondition(notifications <= 1)
if expected == "egy" {
    precondition(!manager.isRightToLeft)
    precondition(NSLocale.isoLanguageCodes.contains("egy"))
    precondition(Locale(identifier: "egy").language.script?.identifier == "Egyp")
    precondition(Bundle.preferredLocalizations(from: available, forPreferences: ["egy-Egyp"]) == ["egy"])
    let path = CommandLine.arguments.last!
    let bundle = Bundle(path: path)!
    let title = bundle.localizedString(forKey: "change.language", value: nil, table: "Localizable")
    precondition(title.unicodeScalars.contains { (0x13000...0x1342F).contains($0.value) })
}
print("passed")
''')
        cls.compile(EXTENSION, APP / "Common/Model/Sora/Language.swift",
                    cls.build / "SettingsKey.swift", cls.build / "main.swift",
                    "-I", cls.build, "-L", cls.build, "-lSoraKeystore", "-lSoraFoundation",
                    "-Xlinker", "-rpath", "-Xlinker", cls.build,
                    "-o", cls.build / "localization-test")

    @classmethod
    def compile(cls, *arguments):
        result = subprocess.run(["xcrun", "swiftc", *map(str, arguments)],
                                cwd=cls.build, capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    def check_manager(self, mode, code="egy-Egyp"):
        result = subprocess.run([str(self.build / "localization-test"), mode, code,
                                 str(APP / "SoraLocalizable/egy.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.strip(), "passed")

    def test_saved_legacy_choice_and_restart_keep_egyptian(self):
        self.check_manager("saved")

    def test_existing_languages_and_unknown_choice_are_not_rewritten(self):
        for code in ["egy", "en", "ja", "akk", "ar", "unrecognized-custom"]:
            with self.subTest(code=code):
                self.check_manager("saved", code)

    def test_missing_resources_do_not_discard_saved_choice(self):
        self.check_manager("unavailable")

    def test_fresh_install_matches_script_qualified_preference(self):
        self.check_manager("fresh")

    def test_shared_manager_normalizes_before_first_consumer(self):
        source = EXTENSION.read_text()
        self.assertRegex(source, r"static let shared = LocalizationManager\(settings: SettingsManager.shared,\s*"
                                 r"key: SettingsKey.selectedLocalization.rawValue\)\s*"
                                 r"\.preservingLegacyEgyptianSelection\(\)")

    def test_bundle_and_project_use_one_language_only_identifier(self):
        self.assertFalse((APP / "SoraLocalizable/egy-Egyp.lproj").exists())
        project = ROOT / "SoraPassport.xcodeproj/project.pbxproj"
        parsed = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", project]))
        objects = parsed["objects"]
        regions = objects[parsed["rootObject"]]["knownRegions"]
        self.assertEqual(regions.count("egy"), 1)
        self.assertNotIn("egy-Egyp", project.read_text())
        for suffix in ["Localizable.strings", "Localizable.stringsdict", "InfoPlist.strings"]:
            resource = APP / "SoraLocalizable/egy.lproj" / suffix
            subprocess.run(["plutil", "-lint", str(resource)], check=True, capture_output=True)
            references = [identifier for identifier, value in objects.items()
                          if value.get("path") == "egy.lproj/" + suffix]
            self.assertEqual(len(references), 1)
            self.assertTrue(any(value.get("isa") == "PBXVariantGroup" and references[0] in value["children"]
                                for value in objects.values()))
        picker = (APP / "ModulesRedesign/Language/LanguagePresenter.swift").read_text()
        self.assertIn('middleEgyptianCode = "egy"', picker)
        self.assertIn('middleEgyptianTitle = "Middle Egyptian (Hieroglyphic)"', picker)
        self.assertIn('middleEgyptianNativeTitle = "𓌃𓂧𓅱𓀁 𓈖 𓆎𓅓𓏏𓊖"', picker)

    def test_generator_targets_packaged_resources_and_keeps_frozen_font(self):
        generator = self.generator()
        self.assertEqual(generator.TARGET, APP / "SoraLocalizable/egy.lproj/Localizable.strings")
        generator.validate_bundled_font()

    @staticmethod
    def generator():
        spec = importlib.util.spec_from_file_location("egyptian_generator", APP / "Scripts/generate-middle-egyptian-localization.py")
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        return generator

    @contextlib.contextmanager
    def catalogs(self):
        generator = self.generator()
        with tempfile.TemporaryDirectory(prefix="sora-egyptian-catalog-") as temporary:
            source = generator.SOURCE.read_text()
            target = generator.TARGET.read_text()
            generator.SOURCE = Path(temporary) / "en.strings"
            generator.TARGET = Path(temporary) / "egy.strings"
            generator.SOURCE.write_text(source)
            generator.TARGET.write_text(target)
            yield generator

    def test_all_original_translations_and_explicit_fallback_validate(self):
        generator = self.generator()
        core, fallback = generator.parse_source_catalog()
        self.assertEqual(len(core), 952)
        self.assertEqual(len(fallback), 150)
        self.assertTrue(all(key == value for key, value in fallback))
        generator.generate(check=True)

    def test_fallback_requires_exactly_one_declaration(self):
        for marker_count in [0, 2]:
            with self.subTest(marker_count=marker_count), self.catalogs() as generator:
                content = generator.SOURCE.read_text()
                content = content.replace(generator.FALLBACK_SECTION, (generator.FALLBACK_SECTION + "\n") * marker_count)
                generator.SOURCE.write_text(content)
                with self.assertRaises(ValueError):
                    generator.generate(check=True)

    def test_fallback_rejects_nonliteral_and_empty_keys(self):
        for entry in ['"Fallback key" = "Different value";', '"" = "";']:
            with self.subTest(entry=entry), self.catalogs() as generator:
                generator.SOURCE.write_text(generator.SOURCE.read_text() + entry + "\n")
                with self.assertRaises(ValueError):
                    generator.generate(check=True)

    def test_duplicate_fallback_and_core_override_are_rejected(self):
        for duplicate_core in [False, True]:
            with self.subTest(duplicate_core=duplicate_core), self.catalogs() as generator:
                core, fallback = generator.parse_source_catalog()
                key, value = (core if duplicate_core else fallback)[0]
                generator.SOURCE.write_text(generator.SOURCE.read_text() + f'"{key}" = "{value}";\n')
                with self.assertRaises(ValueError):
                    generator.generate(check=True)

    def test_escaped_duplicate_key_is_rejected(self):
        with self.catalogs() as generator:
            content = generator.SOURCE.read_text()
            generator.SOURCE.write_text(content + r'"\u0049ndexed DPM pricing curve" = "Indexed DPM pricing curve";' + "\n")
            with self.assertRaisesRegex(ValueError, "duplicate catalog key"):
                generator.generate(check=True)

    def test_reviewed_import_and_onboarding_source_changes_require_review(self):
        for key in ["import.account.message", "onboarding.description"]:
            with self.subTest(key=key), self.catalogs() as generator:
                content = generator.SOURCE.read_text()
                current = generator.REVIEWED_SOURCE_VALUES[key]
                self.assertIn(current, content)
                generator.SOURCE.write_text(content.replace(current, current + " Changed.", 1))
                with self.assertRaisesRegex(ValueError, "English source changed"):
                    generator.generate(check=True)

    def test_existing_translation_cannot_be_reclassified_as_fallback(self):
        with self.catalogs() as generator:
            content = generator.SOURCE.read_text()
            line = next(line for line in content.splitlines() if generator.STRING_RE.match(line))
            key = generator.STRING_RE.match(line).group("key")
            generator.SOURCE.write_text(content.replace(line + "\n", "", 1) + f'"{key}" = "{key}";\n')
            with self.assertRaisesRegex(ValueError, "cannot become English fallback"):
                generator.generate(check=True)

    def test_missing_original_source_translation_is_rejected(self):
        with self.catalogs() as generator:
            content = generator.SOURCE.read_text()
            line = next(line for line in content.splitlines() if generator.STRING_RE.match(line))
            generator.SOURCE.write_text(content.replace(line + "\n", "", 1))
            with self.assertRaises(SystemExit):
                generator.generate(check=True)

    def test_missing_or_changed_egyptian_translation_is_rejected(self):
        for remove in [False, True]:
            with self.subTest(remove=remove), self.catalogs() as generator:
                content = generator.TARGET.read_text()
                line = next(line for line in content.splitlines() if generator.STRING_RE.match(line))
                key = generator.STRING_RE.match(line).group("key")
                replacement = "" if remove else f'"{key}" = "Changed";'
                generator.TARGET.write_text(content.replace(line, replacement, 1))
                with self.assertRaises((SystemExit, ValueError)):
                    generator.generate(check=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
