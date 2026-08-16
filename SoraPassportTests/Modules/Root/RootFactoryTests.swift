import XCTest
@testable import SoraPassport
import SoraKeystore
import IrohaCrypto
import SSFUtils

class RootFactoryTests: XCTestCase {
    func testMainWalletRequiresConnectedNodeAndRuntimeSnapshot() {
        XCTAssertFalse(
            MainTabBarViewFactory.isNetworkReady(
                connectionState: .notConnected,
                hasRuntimeSnapshot: true
            )
        )
        XCTAssertFalse(
            MainTabBarViewFactory.isNetworkReady(
                connectionState: .connected,
                hasRuntimeSnapshot: false
            )
        )
        XCTAssertTrue(
            MainTabBarViewFactory.isNetworkReady(
                connectionState: .connected,
                hasRuntimeSnapshot: true
            )
        )
    }

    func testPresenterCreation() {
        let optionalPresenter = RootPresenterFactory.createPresenter(with: SoraWindow()) as? RootPresenter

        guard let presenter = optionalPresenter else {
            XCTFail()
            return
        }

        XCTAssertNotNil(presenter.view)
        XCTAssertNotNil(presenter.wireframe)

        guard let interactor = presenter.interactor as? RootInteractor else {
            XCTFail()
            return
        }

        XCTAssertNotNil(interactor.presenter)
    }

    func testRetainedAccountRepairRestoresPublicMetadataForRecoveryPreview() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let publicKey = try XCTUnwrap(
            Data(base64Encoded: "lrdnIMLWBHSZqCoUEFhFt9KKOyypgSa4PKfyetYQsFc=")
        )
        let account = AccountItem(
            address: "cnUtu96yy6VdFr1KqsYJ12pDmxE8RAJWp9Tyvbo83KKdSD9z5",
            cryptoType: .sr25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "retained",
            publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: false
        )
        settings.set(value: true, for: "walletMigrationRecoveryRequired")
        settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)

        let repairPlan = try XCTUnwrap(
            SelectedWalletSettings.retainedAccountRepairPlan(
                settings: settings,
                keystore: keychain
            )
        )

        XCTAssertEqual(repairPlan.account.address, account.address)
        XCTAssertTrue(repairPlan.account.isSelected)
        XCTAssertEqual(settings.bool(for: "walletMigrationRecoveryRequired"), true)
        XCTAssertTrue(
            SelectedWalletSettings.requiresRecoveryReadOnlyMode(
                settings: settings,
                keystore: keychain,
                account: repairPlan.account
            )
        )
    }

    func testRetainedAccountRepairRejectsUnverifiedSigningMaterial() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let publicKey = try XCTUnwrap(
            Data(base64Encoded: "lrdnIMLWBHSZqCoUEFhFt9KKOyypgSa4PKfyetYQsFc=")
        )
        let account = AccountItem(
            address: "cnUtu96yy6VdFr1KqsYJ12pDmxE8RAJWp9Tyvbo83KKdSD9z5",
            cryptoType: .sr25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "retained",
            publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: false
        )
        settings.set(value: true, for: "walletMigrationRecoveryRequired")
        settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        try keychain.saveSecretKey(Data(repeating: 1, count: 32), address: account.address)

        XCTAssertNil(
            try SelectedWalletSettings.retainedAccountRepairPlan(
                settings: settings,
                keystore: keychain
            )
        )
    }

    func testRetainedAccountRepairRejectsTamperedIdentity() throws {
        let settings = InMemorySettingsManager()
        let publicKey = try XCTUnwrap(
            Data(base64Encoded: "lrdnIMLWBHSZqCoUEFhFt9KKOyypgSa4PKfyetYQsFc=")
        )
        let account = AccountItem(
            address: "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm",
            cryptoType: .sr25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "tampered",
            publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: false
        )
        settings.set(value: true, for: "walletMigrationRecoveryRequired")
        settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)

        XCTAssertNil(
            try SelectedWalletSettings.retainedAccountRepairPlan(
                settings: settings,
                keystore: InMemoryKeychain()
            )
        )
    }

    @MainActor
    func testRecoveryWalletPreviewLocksWalletInteractions() throws {
        let controller = MainTabBarViewController()
        controller.viewControllers = [UIViewController()]
        controller.loadViewIfNeeded()
        controller.enableRecoveryReadOnlyMode()

        let interactionShield = try XCTUnwrap(controller.recoveryInteractionShield)
        XCTAssertEqual(controller.selectedIndex, MainTabBarViewFactory.walletIndex)
        XCTAssertTrue(interactionShield.isUserInteractionEnabled)
        XCTAssertTrue(interactionShield.isDescendant(of: controller.view))
        XCTAssertTrue(controller.view.subviews.last === interactionShield)
        XCTAssertTrue(interactionShield.accessibilityViewIsModal)
    }

    func testVerifiedSigningKeyClearsRecoveryMode() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let keypair = try SNKeyFactory().createKeypair(fromSeed: Data(repeating: 7, count: 32))
        let publicKey = keypair.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: ApplicationConfig.shared.addressType
        )
        let account = AccountItem(
            address: address,
            cryptoType: .sr25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "restored",
            publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: true
        )
        settings.set(value: true, for: "walletMigrationRecoveryRequired")
        settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        try keychain.saveSecretKey(keypair.privateKey().rawData(), address: address)

        XCTAssertFalse(
            SelectedWalletSettings.requiresRecoveryReadOnlyMode(
                settings: settings,
                keystore: keychain,
                account: account
            )
        )
        XCTAssertEqual(settings.bool(for: "walletMigrationRecoveryRequired"), nil)
    }

    func testRecoveryImportAcceptsOnlyVerifiedRetainedIdentity() throws {
        let keychain = InMemoryKeychain()
        let keypair = try SNKeyFactory().createKeypair(fromSeed: Data(repeating: 9, count: 32))
        let publicKey = keypair.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: ApplicationConfig.shared.addressType
        )
        let account = AccountItem(
            address: address,
            cryptoType: .sr25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "recovery",
            publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: true
        )
        try keychain.saveSecretKey(keypair.privateKey().rawData(), address: address)

        XCTAssertTrue(
            AddAccountImportInteractor.isValidRecoveryReplacement(
                account,
                expected: account,
                existing: account,
                keystore: keychain
            )
        )

        let differentKeypair = try SNKeyFactory().createKeypair(
            fromSeed: Data(repeating: 10, count: 32)
        )
        let differentAccount = AccountItem(
            address: address,
            cryptoType: .sr25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "wrong",
            publicKeyData: differentKeypair.publicKey().rawData(),
            settings: account.settings,
            order: 0,
            isSelected: true
        )
        XCTAssertFalse(
            AddAccountImportInteractor.isValidRecoveryReplacement(
                differentAccount,
                expected: account,
                existing: account,
                keystore: keychain
            )
        )
    }

}
