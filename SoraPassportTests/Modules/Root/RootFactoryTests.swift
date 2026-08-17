import XCTest
@testable import SoraPassport
import SoraKeystore
import IrohaCrypto
import SSFUtils
import SSFCrypto

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

    func testRetainedAccountRepairRestoresPublicMetadataForBrowseOnlyWallet() throws {
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
        XCTAssertFalse(
            SelectedWalletSettings.requiresRecoveryReadOnlyMode(
                settings: settings,
                keystore: keychain,
                account: repairPlan.account
            )
        )
    }

    func testRetainedAccountRepairKeepsPreviewForUnverifiedSigningMaterial() throws {
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

        let repairPlan = try XCTUnwrap(
            SelectedWalletSettings.retainedAccountRepairPlan(
                settings: settings,
                keystore: keychain
            )
        )
        XCTAssertEqual(repairPlan.account.address, account.address)
        XCTAssertTrue(repairPlan.account.isSelected)
        XCTAssertTrue(
            SelectedWalletSettings.requiresRecoveryReadOnlyMode(
                settings: settings,
                keystore: keychain,
                account: repairPlan.account
            )
        )
        XCTAssertEqual(
            settings.bool(for: "walletMigrationRecoveryRequired"),
            true
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

    func testLegacyEntropyAutomaticallyRepairsRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let entropy = Data((0 ..< 20).map(UInt8.init))
        let fixture = try makeMnemonicRecoveryFixture(entropy: entropy)
        markRecoveryRequired(settings: settings, account: fixture.account)
        settings.set(value: "retained migration", for: "walletMigrationRecoveryReason")
        try keychain.saveKey(entropy, with: KeystoreTag.legacyEntropy.rawValue)

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertTrue(
            SelectedWalletSettings.hasVerifiedSigningKey(
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertEqual(
            try keychain.fetchSeedForAddress(fixture.account.address),
            fixture.seed
        )
        XCTAssertEqual(
            try keychain.fetchEntropyForAddress(fixture.account.address),
            entropy
        )
        XCTAssertEqual(
            try keychain.fetchKey(for: KeystoreTag.legacyEntropy.rawValue),
            entropy
        )
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
        XCTAssertNil(settings.string(for: "walletMigrationRecoveryReason"))

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertTrue(
            SelectedWalletSettings.hasVerifiedSigningKey(
                keystore: keychain,
                account: fixture.account
            )
        )
    }

    func testMismatchedLegacyEntropyDoesNotRepairRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map(UInt8.init))
        )
        let differentEntropy = Data((1 ... 20).map(UInt8.init))
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveKey(
            differentEntropy,
            with: KeystoreTag.legacyEntropy.rawValue
        )

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertFalse(
            try keychain.checkSecretKeyForAddress(fixture.account.address)
        )
        XCTAssertEqual(
            settings.bool(for: "walletMigrationRecoveryRequired"),
            true
        )
    }

    func testConsistentScopedEntropyAndSeedRepairRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let entropy = Data((0 ..< 16).map { UInt8($0 + 31) })
        let fixture = try makeMnemonicRecoveryFixture(entropy: entropy)
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveEntropy(entropy, address: fixture.account.address)
        try keychain.saveSeed(fixture.seed, address: fixture.account.address)

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testRawSeedRecoveryPreservesFullSeedLongerThanMiniSeed() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let entropy = Data((0 ..< 16).map { UInt8($0 + 63) })
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: entropy)
        let fullSeed = try SeedFactory()
            .deriveSeed(from: mnemonic.toString(), password: "")
            .seed
        XCTAssertGreaterThan(fullSeed.count, fullSeed.miniSeed.count)
        let fixture = try makeRawSeedRecoveryFixture(seed: fullSeed)
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveSeed(fullSeed, address: fixture.account.address)

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchSeedForAddress(fixture.account.address),
            fullSeed
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testConflictingScopedEntropyAndSeedFailClosed() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let entropy = Data((0 ..< 16).map { UInt8($0 + 47) })
        let fixture = try makeMnemonicRecoveryFixture(entropy: entropy)
        let conflictingFixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map { UInt8($0 + 79) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveEntropy(entropy, address: fixture.account.address)
        try keychain.saveSeed(
            conflictingFixture.seed,
            address: fixture.account.address
        )

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertFalse(
            try keychain.checkSecretKeyForAddress(fixture.account.address)
        )
        XCTAssertEqual(
            settings.bool(for: "walletMigrationRecoveryRequired"),
            true
        )
    }

    func testInvalidScopedSecretIsNeverOverwrittenByLegacyEntropy() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let entropy = Data((0 ..< 20).map { UInt8($0 + 101) })
        let fixture = try makeMnemonicRecoveryFixture(entropy: entropy)
        let invalidSecret = Data(repeating: 1, count: fixture.secretKey.count)
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveSecretKey(invalidSecret, address: fixture.account.address)
        try keychain.saveKey(entropy, with: KeystoreTag.legacyEntropy.rawValue)

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            invalidSecret
        )
        XCTAssertEqual(
            settings.bool(for: "walletMigrationRecoveryRequired"),
            true
        )
    }

    func testLegacyPrivateKeyAloneIsNeverPromotedToSora2Signer() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 17) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveKey(Data(repeating: 3, count: 32), with: "privateKey")

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertFalse(
            try keychain.checkSecretKeyForAddress(fixture.account.address)
        )
        XCTAssertEqual(
            settings.bool(for: "walletMigrationRecoveryRequired"),
            true
        )
    }

    func testMalformedLegacyKeysNeverBecomeRetainedWalletSigner() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 23) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveKey(Data(repeating: 0xa5, count: 31), with: "privateKey")
        try keychain.saveKey(Data(repeating: 0x5a, count: 32), with: "ethKey")

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertFalse(
            try keychain.checkSecretKeyForAddress(fixture.account.address)
        )
        XCTAssertEqual(settings.bool(for: "walletMigrationRecoveryRequired"), true)
    }

    func testSigningIsBlockedWhileRetainedRecoveryMarkerRemains() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 29) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveSecretKey(
            fixture.secretKey,
            address: fixture.account.address
        )

        let signer = SigningWrapper(
            keystore: keychain,
            account: fixture.account,
            recoverySettings: settings
        )

        XCTAssertThrowsError(try signer.sign(Data("blocked".utf8))) { error in
            guard case SigningWrapperError.retainedWalletRecoveryRequired = error else {
                return XCTFail("Unexpected signing error: \(error)")
            }
        }
    }

    func testVerifiedLegacyPrivateKeySeedRepairsRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 37) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveKey(fixture.seed, with: "privateKey")

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertEqual(
            try keychain.fetchSeedForAddress(fixture.account.address),
            fixture.seed
        )
        XCTAssertEqual(try keychain.fetchKey(for: "privateKey"), fixture.seed)
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testRetainedRepairPlanKeepsPreviewWhenScopedMaterialIsUnrecoverable() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map { UInt8($0 + 3) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveSeed(
            Data(repeating: 0xff, count: fixture.seed.count),
            address: fixture.account.address
        )

        let plan = try XCTUnwrap(
            SelectedWalletSettings.retainedAccountRepairPlan(
                settings: settings,
                keystore: keychain
            )
        )

        XCTAssertEqual(plan.account.address, fixture.account.address)
        XCTAssertTrue(plan.account.isSelected)
        XCTAssertEqual(
            settings.bool(for: "walletMigrationRecoveryRequired"),
            true
        )
    }

    private func makeMnemonicRecoveryFixture(
        entropy: Data
    ) throws -> (account: AccountItem, seed: Data, secretKey: Data) {
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: entropy)
        let seed = try SeedFactory()
            .deriveSeed(from: mnemonic.toString(), password: "")
            .seed
            .miniSeed
        let keypair = try SR25519KeypairFactory()
            .createKeypairFromSeed(seed, chaincodeList: [])
        let publicKey = keypair.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: ApplicationConfig.shared.addressType
        )
        let account = AccountItem(
            address: address,
            cryptoType: .sr25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "retained",
            publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: true
        )
        return (account, seed, keypair.privateKey().rawData())
    }

    private func makeRawSeedRecoveryFixture(
        seed: Data
    ) throws -> (account: AccountItem, secretKey: Data) {
        let factory = Ed25519KeypairFactory()
        let keypair = try factory.createKeypairFromSeed(seed, chaincodeList: [])
        let publicKey = keypair.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: ApplicationConfig.shared.addressType
        )
        let account = AccountItem(
            address: address,
            cryptoType: .ed25519,
            networkType: ApplicationConfig.shared.addressType,
            username: "raw seed",
            publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: true
        )
        let secretKey = try factory.deriveChildSeedFromParent(
            seed.miniSeed,
            chaincodeList: []
        )
        return (account, secretKey)
    }

    private func markRecoveryRequired(
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) {
        settings.set(value: true, for: "walletMigrationRecoveryRequired")
        settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
    }

}
