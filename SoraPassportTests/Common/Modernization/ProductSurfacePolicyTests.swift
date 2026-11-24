// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import UIKit
import SoraFoundation
import SoraKeystore
import XCTest
@testable import SoraPassport

/// Taira, Polkamarkt, the Nexus portfolio and IrohaConnect ship in every
/// configuration. The 3.9.x App Store line's switch that hid them in Release
/// was removed on 2026-11-18; PI and stored settings still decide.
final class ProductSurfacePolicyTests: XCTestCase {
    func testEveryOptionalSurfaceIsOnForAFreshInstall() {
        let fresh = InMemorySettingsManager()
        XCTAssertTrue(fresh.nexusEnabled)
        XCTAssertTrue(fresh.polkamarktEnabled)
        XCTAssertTrue(fresh.isTairaEnabled)
    }

    func testIrohaConnectLinksAreAccepted() throws {
        for scheme in ["iroha", "irohaconnect"] {
            let url = try XCTUnwrap(URL(string: "\(scheme)://connect?v=1"))
            XCTAssertTrue(IrohaConnectCoordinator.shared.canHandle(url))
        }
    }

    func testIrohaConnectURLSchemesAreRegistered() {
        let types = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleURLTypes"
        ) as? [[String: Any]] ?? []
        let schemes = types.flatMap {
            $0["CFBundleURLSchemes"] as? [String] ?? []
        }
        XCTAssertTrue(schemes.contains("irohaconnect"))
        XCTAssertTrue(schemes.contains("iroha"))
        // Google Sign-In stays the first URL type (its callback scheme is
        // written to index 0 at build time).
        XCTAssertFalse(
            (types.first?["CFBundleURLSchemes"] as? [String] ?? [])
                .contains("irohaconnect")
        )
    }
}

/// Middle Egyptian stays selectable using app-owned resources. Apple sees
/// only supported .lproj directories; stored language choices are retained.
final class ShippedLocalizationTests: XCTestCase {
    func testNexusLinePackagesItsTesterLocales() {
        let shipped = Set(Bundle.main.localizations)
        XCTAssertTrue(shipped.contains("akk"))
        XCTAssertFalse(shipped.contains("egy-Egyp"))
        XCTAssertTrue(shipped.contains("en"))
        XCTAssertTrue(shipped.contains("ja"))
        XCTAssertNotNil(Bundle.main.path(forResource: "akk", ofType: "lproj"))
        XCTAssertNil(Bundle.main.path(forResource: "egy-Egyp", ofType: "lproj"))
        XCTAssertNotNil(R.languageBundle("egy-Egyp"))
        XCTAssertTrue(LocalizationManager.shared.availableLocalizations.contains("egy-Egyp"))
        let fonts = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts")
            as? [String] ?? []
        XCTAssertTrue(fonts.contains("NotoSansEgyptianHieroglyphs-Regular.ttf"))
        XCTAssertNotNil(UIFont(name: "NotoSansEgyptianHieroglyphs-Regular", size: 12))
    }

    func testMiddleEgyptianTranslationsAndStoredSelectionSurvivePackaging() throws {
        let bundle = try XCTUnwrap(R.languageBundle("egy-Egyp"))
        let key = "change.language"
        let expected = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        XCTAssertNotEqual(expected, key)
        XCTAssertNotEqual(expected, R.string.localizable.changeLanguage(preferredLanguages: ["en"]))
        XCTAssertEqual(R.string.localizable.changeLanguage(preferredLanguages: ["egy-Egyp"]), expected)
        XCTAssertEqual(WalletUX.text(key, language: "egy-Egyp"), expected)
        XCTAssertEqual(L10n.getFormat(for: key, localization: "egy-Egyp", bundle: .main), expected)
        XCTAssertEqual(R.string.localizable.commonFarms(preferredLanguages: ["egy-Egyp"]), "𓄿𓎛𓅱𓏏")

        let settings = InMemorySettingsManager()
        settings.set(value: "egy-Egyp", for: "language")
        let manager = LocalizationManager(settings: settings, key: "language",
                                          availableLocalizations: LocalizationManager.appLanguages)
        manager.replaceUnavailableSelection(preferredLanguages: ["en"])
        XCTAssertEqual(manager.selectedLocalization, "egy-Egyp")
        XCTAssertEqual(settings.string(for: "language"), "egy-Egyp")
    }

    func testStoredRemovedLocaleFallsBackToAShippedOne() throws {
        for removed in ["akk", "egy-Egyp"] {
            let settings = InMemorySettingsManager()
            settings.set(value: removed, for: "language")
            let manager = LocalizationManager(
                settings: settings,
                key: "language",
                availableLocalizations: ["en", "ja", "ru"]
            )
            XCTAssertEqual(manager.selectedLocalization, removed)

            manager.replaceUnavailableSelection(preferredLanguages: ["ja-JP"])
            XCTAssertEqual(manager.selectedLocalization, "ja")
            XCTAssertEqual(settings.string(for: "language"), "ja")

            settings.set(value: removed, for: "language")
            let other = LocalizationManager(
                settings: settings,
                key: "language",
                availableLocalizations: ["en", "ja", "ru"]
            )
            other.replaceUnavailableSelection(preferredLanguages: ["xx"])
            XCTAssertEqual(other.selectedLocalization, "en")
        }
    }

    func testStoredRegionalVariantKeepsItsLanguage() {
        // 1.5.1 shipped es-CO; 3.9.0 ships es. An English device must not
        // switch a Spanish user to English.
        let settings = InMemorySettingsManager()
        settings.set(value: "es-CO", for: "language")
        let manager = LocalizationManager(
            settings: settings,
            key: "language",
            availableLocalizations: ["en", "es", "ja"]
        )
        manager.replaceUnavailableSelection(preferredLanguages: ["en-US"])
        XCTAssertEqual(manager.selectedLocalization, "es")
        XCTAssertEqual(settings.string(for: "language"), "es")

        // A regional variant whose language is not shipped still falls back
        // to the device language.
        settings.set(value: "ba-RU", for: "language")
        let other = LocalizationManager(
            settings: settings,
            key: "language",
            availableLocalizations: ["en", "es", "ja"]
        )
        other.replaceUnavailableSelection(preferredLanguages: ["ja-JP"])
        XCTAssertEqual(other.selectedLocalization, "ja")
    }

    func testShippedSelectionIsKept() {
        let settings = InMemorySettingsManager()
        settings.set(value: "ru", for: "language")
        let manager = LocalizationManager(
            settings: settings,
            key: "language",
            availableLocalizations: ["en", "ja", "ru"]
        )
        manager.replaceUnavailableSelection(preferredLanguages: ["ja"])
        XCTAssertEqual(manager.selectedLocalization, "ru")
    }
}

/// Privacy manifest and permission strings shipped with 3.9.0.
final class PrivacyDeclarationTests: XCTestCase {
    private func manifest(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        )
    }

    private func accessedCategories(_ manifest: [String: Any]) -> Set<String> {
        let types = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        return Set(types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
    }

    func testAppManifestDeclaresEveryRequiredReasonAPIInUse() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
        )
        let app = try manifest(at: url)
        XCTAssertEqual(
            accessedCategories(app),
            [
                "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPICategoryFileTimestamp",
                "NSPrivacyAccessedAPICategoryDiskSpace",
                "NSPrivacyAccessedAPICategorySystemBootTime"
            ]
        )
        XCTAssertEqual(app["NSPrivacyTracking"] as? Bool, false)
        let collected = (app["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? [])
        // No analytics or crash SDK is linked, so only data the wallet itself
        // needs is collected (Google Drive backup, indexer requests).
        let linkedTypes: Set<String> = [
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypeOtherFinancialInfo"
        ]
        XCTAssertEqual(Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }), linkedTypes)
        XCTAssertEqual(collected.count, linkedTypes.count)
        for item in collected {
            XCTAssertEqual(item["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
            XCTAssertEqual(item["NSPrivacyCollectedDataTypeLinked"] as? Bool, true)
            XCTAssertEqual(item["NSPrivacyCollectedDataTypePurposes"] as? [String],
                           ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
        }
    }

    func testNoPrebuiltWalletFrameworkIsEmbedded() throws {
        // The indexer models used to come from a prebuilt Kotlin/Native
        // sorawallet.framework; they are Swift source in VendorPackages now.
        let frameworks = try XCTUnwrap(Bundle.main.privateFrameworksURL)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: frameworks.appendingPathComponent("sorawallet.framework").path))
        XCTAssertNil(NSClassFromString("SorawalletBase"))
    }

    func testPermissionStringsMatchWhatTheAppUses() {
        let info = Bundle.main.infoDictionary ?? [:]
        XCTAssertNil(info["NSMicrophoneUsageDescription"])
        for key in [
            "NSCameraUsageDescription",
            "NSFaceIDUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSPhotoLibraryAddUsageDescription"
        ] {
            let value = info[key] as? String ?? ""
            XCTAssertTrue(value.hasPrefix("SORA Wallet "), key)
            for language in ["en", "ja"] {
                guard
                    let path = Bundle.main.path(forResource: language, ofType: "lproj"),
                    let bundle = Bundle(path: path)
                else {
                    return XCTFail("Missing \(language).lproj")
                }
                let localized = bundle.localizedString(
                    forKey: key,
                    value: nil,
                    table: "InfoPlist"
                )
                XCTAssertNotEqual(localized, key, "\(language) \(key)")
                if language == "en" {
                    XCTAssertEqual(localized, value, key)
                }
            }
        }
    }

    /// The backup warnings said "you will loose your wallet" (English and 23 copies) and "full
    /// reponsibility" (14 copies of the English export warnings). Android fixed the same text.
    func testShippedWarningsAreSpelledCorrectlyInEveryLanguage() throws {
        let tables = Bundle.main.paths(forResourcesOfType: "lproj", inDirectory: nil)
            .compactMap { lproj -> (String, [String: String])? in
                let path = (lproj as NSString).appendingPathComponent("Localizable.strings")
                guard let table = NSDictionary(contentsOfFile: path) as? [String: String] else {
                    return nil
                }
                return ((lproj as NSString).lastPathComponent, table)
            }
        XCTAssertGreaterThan(tables.count, 20)
        for (language, table) in tables {
            for (key, value) in table {
                let lowered = value.lowercased()
                XCTAssertFalse(lowered.contains("loose your"), "\(language) \(key)")
                XCTAssertFalse(lowered.contains("reponsibility"), "\(language) \(key)")
            }
        }
        let english = try XCTUnwrap(tables.first { $0.0 == "en.lproj" }?.1)
        XCTAssertEqual(
            english["import.account.not.backed.up.alert.description"],
            "If your device gets lost or stolen, you will lose your wallet and all your funds forever."
        )
    }
}
