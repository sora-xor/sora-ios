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
