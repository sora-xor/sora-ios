// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import SoraFoundation
import SoraKeystore
import XCTest
@testable import SoraPassport

/// App Store (Release) builds hide Taira, Polkamarkt and the Nexus portfolio,
/// and do not register or accept IrohaConnect links. Other configurations
/// keep them for testers. CI runs these tests in Debug and in Release.
final class ProductSurfacePolicyTests: XCTestCase {
    private var isAppStoreConfiguration: Bool {
        Bundle.main.object(forInfoDictionaryKey: "AppConfigName") as? String
            == "Release"
    }

    func testOptionalSurfacesAreHiddenOnlyInAppStoreBuilds() {
        let expected = !isAppStoreConfiguration
        XCTAssertEqual(ProductSurfacePolicy.showsTairaSettings, expected)
        XCTAssertEqual(ProductSurfacePolicy.showsPolkamarkt, expected)
        XCTAssertEqual(ProductSurfacePolicy.showsNexusPortfolio, expected)
        XCTAssertEqual(ProductSurfacePolicy.acceptsIrohaConnect, expected)
    }

    func testIrohaConnectLinksFollowThePolicy() throws {
        for scheme in ["iroha", "irohaconnect"] {
            let url = try XCTUnwrap(URL(string: "\(scheme)://connect?v=1"))
            XCTAssertEqual(
                IrohaConnectCoordinator.shared.canHandle(url),
                ProductSurfacePolicy.acceptsIrohaConnect
            )
        }
    }

    func testIrohaConnectURLSchemesAreRegisteredOnlyOutsideAppStoreBuilds() {
        let types = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleURLTypes"
        ) as? [[String: Any]] ?? []
        let schemes = types.flatMap {
            $0["CFBundleURLSchemes"] as? [String] ?? []
        }
        XCTAssertEqual(
            schemes.contains("irohaconnect"),
            !isAppStoreConfiguration
        )
        XCTAssertEqual(schemes.contains("iroha"), !isAppStoreConfiguration)
        // Google Sign-In stays the first URL type (its callback scheme is
        // written to index 0 at build time).
        XCTAssertFalse(
            (types.first?["CFBundleURLSchemes"] as? [String] ?? [])
                .contains("irohaconnect")
        )
    }
}

/// Old Akkadian and Middle Egyptian were tester-only locales. 3.9.0 packages
/// the same locales as App Store 3.8.6, and a stored choice of a removed
/// locale falls back to a shipped one.
final class ShippedLocalizationTests: XCTestCase {
    func testRemovedLocalesAreNotPackaged() {
        let shipped = Set(Bundle.main.localizations)
        XCTAssertFalse(shipped.contains("akk"))
        XCTAssertFalse(shipped.contains("egy-Egyp"))
        XCTAssertTrue(shipped.contains("en"))
        XCTAssertTrue(shipped.contains("ja"))
        XCTAssertNil(Bundle.main.path(forResource: "akk", ofType: "lproj"))
        XCTAssertNil(Bundle.main.path(forResource: "egy-Egyp", ofType: "lproj"))
        let fonts = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts")
            as? [String] ?? []
        XCTAssertFalse(fonts.contains { $0.contains("Egyptian") })
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
        XCTAssertFalse(collected.isEmpty)
        for item in collected {
            XCTAssertEqual(item["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
            XCTAssertEqual(item["NSPrivacyCollectedDataTypeLinked"] as? Bool, false)
        }
    }

    func testEmbeddedWalletFrameworkHasItsOwnManifest() throws {
        let url = try XCTUnwrap(Bundle.main.privateFrameworksURL)
            .appendingPathComponent("sorawallet.framework/PrivacyInfo.xcprivacy")
        let framework = try manifest(at: url)
        XCTAssertEqual(
            accessedCategories(framework),
            [
                "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPICategorySystemBootTime"
            ]
        )
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
}
