// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
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

