import XCTest
@testable import SoraPassport
import SoraKeystore
import IrohaCrypto
import SSFUtils
import SSFCrypto
import SSFCloudStorage

class RootFactoryTests: XCTestCase {
    func testSafeSr25519ValidatorContainsPanicsInsideItsFFIBoundary() {
        XCTAssertTrue(SNSafeKeypairValidator.containsForcedPanicForReleaseValidation())
    }

    func testMainWalletRequiresConnectedNodeWithoutBlockingOnRuntimeSnapshot() {
        XCTAssertFalse(
            MainTabBarViewFactory.isNetworkReady(
                connectionState: .notConnected
            )
        )
        XCTAssertTrue(
            MainTabBarViewFactory.isNetworkReady(
                connectionState: .connected
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
        try keychain.saveSecretKey(Data(repeating: 0xff, count: 64), address: account.address)

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

    @MainActor
    func testSuccessfulBackgroundRecoveryRemovesExistingInteractionShield() throws {
        let controller = MainTabBarViewController()
        var recoveryRequired = true
        controller.recoveryRequiredProvider = { recoveryRequired }
        controller.viewControllers = [UIViewController()]
        controller.loadViewIfNeeded()
        controller.enableRecoveryReadOnlyMode()
        XCTAssertNotNil(controller.recoveryInteractionShield)

        recoveryRequired = false
        NotificationCenter.default.post(name: .retainedWalletSigningRestored, object: nil)

        XCTAssertFalse(controller.isRecoveryReadOnly)
        XCTAssertNil(controller.recoveryInteractionShield)
        XCTAssertFalse(controller.tabBar.accessibilityElementsHidden)

        // A factory decision sampled before recovery must not re-enable the shield later.
        controller.enableRecoveryReadOnlyMode()
        XCTAssertFalse(controller.isRecoveryReadOnly)
        XCTAssertNil(controller.recoveryInteractionShield)
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
        try keychain.saveSeed(Data(repeating: 7, count: 32), address: address)

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
        let invalidSecret = Data(repeating: 0xff, count: fixture.secretKey.count)
        let provider = RetainedSigningMaterialCandidateProviderMock(
            candidates: [fixture.secretKey]
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveSecretKey(invalidSecret, address: fixture.account.address)
        try keychain.saveKey(entropy, with: KeystoreTag.legacyEntropy.rawValue)

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account,
                materialCandidateProvider: provider
            )
        )
        XCTAssertEqual(provider.loadCallCount, 0)
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            invalidSecret
        )
        XCTAssertEqual(
            settings.bool(for: "walletMigrationRecoveryRequired"),
            true
        )
    }

    func testValidScopedSecretAloneAutomaticallyRepairsRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 113) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveSecretKey(
            fixture.secretKey,
            address: fixture.account.address
        )

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
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
        XCTAssertNil(settings.string(for: "walletMigrationRecoveryReason"))
    }

    func testUnlabeledSecretProviderIsNotCalledWhenScopedSecretExists() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 117) })
        )
        let provider = RetainedSigningMaterialCandidateProviderMock(
            candidates: [Data(repeating: 0xff, count: 64)]
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        try keychain.saveSecretKey(
            fixture.secretKey,
            address: fixture.account.address
        )

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account,
                materialCandidateProvider: provider
            )
        )
        XCTAssertEqual(provider.loadCallCount, 0)
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
    }

    func testCryptographicallyMatchingUnlabeledSecretRepairsRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 121) })
        )
        let provider = RetainedSigningMaterialCandidateProviderMock(
            candidates: [Data(repeating: 0xff, count: 64), fixture.secretKey]
        )
        markRecoveryRequired(settings: settings, account: fixture.account)

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account,
                materialCandidateProvider: provider
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertTrue(
            SelectedWalletSettings.hasVerifiedSigningKey(
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testCryptographicallyMatchingUnlabeledSeedRepairsRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 122) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account,
                materialCandidateProvider: RetainedSigningMaterialCandidateProviderMock(
                    candidates: [fixture.seed]
                )
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
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testCryptographicallyMatchingUnlabeledEntropyRepairsRetainedWallet() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let entropy = Data((0 ..< 20).map { UInt8($0 + 124) })
        let fixture = try makeMnemonicRecoveryFixture(entropy: entropy)
        markRecoveryRequired(settings: settings, account: fixture.account)

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account,
                materialCandidateProvider: RetainedSigningMaterialCandidateProviderMock(
                    candidates: [entropy]
                )
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertEqual(
            try keychain.fetchEntropyForAddress(fixture.account.address),
            entropy
        )
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testUnlabeledSecretScanNeverPromotesIdentityMismatch() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 123) })
        )
        let unrelatedSecret = try SNKeyFactory()
            .createKeypair(fromSeed: Data(repeating: 0x6a, count: 32))
            .privateKey()
            .rawData()
        markRecoveryRequired(settings: settings, account: fixture.account)

        XCTAssertFalse(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account,
                materialCandidateProvider: RetainedSigningMaterialCandidateProviderMock(
                    candidates: [unrelatedSecret]
                )
            )
        )
        XCTAssertFalse(try keychain.checkSecretKeyForAddress(fixture.account.address))
        XCTAssertEqual(settings.bool(for: "walletMigrationRecoveryRequired"), true)
    }

    func testScopedSecretRepairUsesOnlyBytesValidatedBySafeParser() throws {
        let settings = InMemorySettingsManager()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 127) })
        )
        let replacement = try SNKeyFactory()
            .createKeypair(fromSeed: Data(repeating: 0x42, count: 32))
            .privateKey()
            .rawData()
        let identifier = KeystoreTag.secretKeyTagForAddress(fixture.account.address)
        let keychain = ChangingSecretKeystore(
            identifier: identifier,
            initialValue: fixture.secretKey,
            replacementValue: replacement
        )
        markRecoveryRequired(settings: settings, account: fixture.account)

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(keychain.targetFetchCount, 1)
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testRecoveryRequiredMarkerIsClearedLast() throws {
        let settings = RecordingSettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 139) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)
        settings.set(value: "retained migration", for: "walletMigrationRecoveryReason")
        settings.set(
            value: fixture.account,
            for: "walletMigrationRecoveryExpectedAccount"
        )
        settings.resetMutationTracking()
        try keychain.saveSecretKey(
            fixture.secretKey,
            address: fixture.account.address
        )

        XCTAssertTrue(
            try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(settings.removedKeys.last, "walletMigrationRecoveryRequired")
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

    func testSigningAutomaticallyRepairsValidScopedSecret() throws {
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

        XCTAssertNoThrow(try signer.sign(Data("repaired".utf8)))
        XCTAssertNil(settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testSigningIsBlockedWhenRetainedRecoveryHasNoKey() throws {
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 31) })
        )
        markRecoveryRequired(settings: settings, account: fixture.account)

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
        XCTAssertEqual(
            SelectedWalletSettings.transactionSigningAvailability(
                settings: settings,
                keystore: keychain,
                account: fixture.account
            ),
            .recoveryRequired
        )
        XCTAssertEqual(settings.bool(for: "walletMigrationRecoveryRequired"), true)
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

    func testCloudRecoveryAfterUnlockRestoresOnlyExactVerifiedWallet() async throws {
        let fixture = try makeCloudRecoveryFixture()
        let provider = RetainedSigningMaterialCandidateProviderMock(
            candidates: [fixture.secretKey]
        )
        let service = makeCloudRecoveryService(
            fixture: fixture,
            materialCandidateProvider: provider
        )

        let didRecover = await service.recoverAfterLocalAuthentication(
            protectedDataAvailable: true
        )
        XCTAssertTrue(didRecover)
        XCTAssertEqual(fixture.cloud.restoreCallsCount, 1)
        XCTAssertEqual(fixture.cloud.mobileImportCallsCount, 1)
        XCTAssertEqual(provider.loadCallCount, 0)
        XCTAssertEqual(fixture.cloud.receivedPassword, fixture.pin)
        XCTAssertEqual(fixture.cloud.receivedAddress, fixture.account.address)
        XCTAssertTrue(
            SelectedWalletSettings.hasVerifiedSigningKey(
                keystore: fixture.keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try fixture.keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertEqual(
            try fixture.keychain.fetchSeedForAddress(fixture.account.address),
            fixture.seed
        )
        XCTAssertEqual(
            try fixture.keychain.fetchEntropyForAddress(fixture.account.address),
            fixture.entropy
        )
        XCTAssertNil(fixture.settings.bool(for: "walletMigrationRecoveryRequired"))
        XCTAssertNil(fixture.settings.string(for: "walletMigrationRecoveryReason"))
    }

    func testPostAuthRecoveryUsesCloudBeforeUnlabeledScan() async throws {
        let fixture = try makeCloudRecoveryFixture()
        fixture.cloud.restoreState = .notAuthorized
        let provider = RetainedSigningMaterialCandidateProviderMock(
            candidates: [fixture.secretKey]
        )

        let didRecover = await makeCloudRecoveryService(
            fixture: fixture,
            materialCandidateProvider: provider
        ).recoverAfterLocalAuthentication(protectedDataAvailable: true)

        XCTAssertTrue(didRecover)
        XCTAssertEqual(provider.loadCallCount, 1)
        XCTAssertFalse(provider.wasCalledOnMainThread)
        XCTAssertEqual(fixture.cloud.restoreCallsCount, 1)
        XCTAssertEqual(
            try fixture.keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
        XCTAssertNil(fixture.settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testCloudRecoveryDoesNotRunForOrdinaryLoginOrUnavailableProtectedData() async throws {
        let ordinary = try makeCloudRecoveryFixture()
        ordinary.settings.removeValue(for: "walletMigrationRecoveryRequired")
        ordinary.settings.resetMutationTracking()

        let ordinaryDidRecover = await makeCloudRecoveryService(fixture: ordinary)
            .recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(ordinaryDidRecover)
        XCTAssertEqual(ordinary.cloud.restoreCallsCount, 0)
        try assertCloudRecoveryFailureWasReadOnly(ordinary, expectedMarker: nil)

        let mismatchedMarker = try makeCloudRecoveryFixture()
        let differentIdentity = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map { UInt8($0 + 51) })
        ).account
        mismatchedMarker.settings.set(
            value: differentIdentity,
            for: "walletMigrationRecoveryExpectedAccount"
        )
        mismatchedMarker.settings.resetMutationTracking()
        let mismatchedMarkerDidRecover = await makeCloudRecoveryService(
            fixture: mismatchedMarker
        ).recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(mismatchedMarkerDidRecover)
        XCTAssertEqual(mismatchedMarker.cloud.restoreCallsCount, 0)
        try assertCloudRecoveryFailureWasReadOnly(mismatchedMarker)

        let protectedDataUnavailable = try makeCloudRecoveryFixture()
        let unavailableDataDidRecover = await makeCloudRecoveryService(
            fixture: protectedDataUnavailable
        ).recoverAfterLocalAuthentication(protectedDataAvailable: false)
        XCTAssertFalse(unavailableDataDidRecover)
        XCTAssertEqual(protectedDataUnavailable.cloud.restoreCallsCount, 0)
        try assertCloudRecoveryFailureWasReadOnly(protectedDataUnavailable)

        let missingStoredPin = try makeCloudRecoveryFixture()
        try missingStoredPin.keychain.deleteKey(for: KeystoreTag.pincode.rawValue)
        missingStoredPin.keychain.resetMutationTracking()
        let missingPinDidRecover = await makeCloudRecoveryService(fixture: missingStoredPin)
            .recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(missingPinDidRecover)
        XCTAssertEqual(missingStoredPin.cloud.restoreCallsCount, 0)
        try assertCloudRecoveryFailureWasReadOnly(missingStoredPin)
    }

    func testCloudRecoveryWithoutPreviousGoogleSessionIsNoninteractiveAndReadOnly() async throws {
        let fixture = try makeCloudRecoveryFixture()
        fixture.cloud.restoreState = .notAuthorized

        let didRecover = await makeCloudRecoveryService(fixture: fixture)
            .recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(didRecover)
        XCTAssertEqual(fixture.cloud.restoreCallsCount, 1)
        XCTAssertEqual(fixture.cloud.mobileImportCallsCount, 0)
        try assertCloudRecoveryFailureWasReadOnly(fixture)
    }

    func testCloudRecoveryMissingFileWrongPinAndNetworkErrorAreReadOnly() async throws {
        let errors: [Error] = [
            CloudStorageServiceError.notFound,
            CloudStorageServiceError.incorectPassword,
            CloudRecoveryTestError.network
        ]
        for error in errors {
            let fixture = try makeCloudRecoveryFixture()
            fixture.cloud.mobileImportError = error

            let didRecover = await makeCloudRecoveryService(fixture: fixture)
                .recoverAfterLocalAuthentication(protectedDataAvailable: true)
            XCTAssertFalse(didRecover)
            XCTAssertEqual(fixture.cloud.restoreCallsCount, 1)
            XCTAssertEqual(fixture.cloud.mobileImportCallsCount, 1)
            try assertCloudRecoveryFailureWasReadOnly(fixture)
        }

        let restoreNetworkFailure = try makeCloudRecoveryFixture()
        restoreNetworkFailure.cloud.restoreError = CloudRecoveryTestError.network
        let restoreFailureDidRecover = await makeCloudRecoveryService(
            fixture: restoreNetworkFailure
        ).recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(restoreFailureDidRecover)
        XCTAssertEqual(restoreNetworkFailure.cloud.mobileImportCallsCount, 0)
        try assertCloudRecoveryFailureWasReadOnly(restoreNetworkFailure)
    }

    func testCloudRecoveryIdentityMismatchAndFailedSignatureAreReadOnly() async throws {
        let identityMismatch = try makeCloudRecoveryFixture()
        let differentEntropy = Data((0 ..< 16).map { UInt8($0 + 91) })
        let differentMnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: differentEntropy)
        identityMismatch.cloud.mobileImportResult?.passphrase = differentMnemonic.toString()

        let identityMismatchDidRecover = await makeCloudRecoveryService(
            fixture: identityMismatch
        ).recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(identityMismatchDidRecover)
        try assertCloudRecoveryFailureWasReadOnly(identityMismatch)

        let failedSignature = try makeCloudRecoveryFixture()
        let failedSignatureDidRecover = await makeCloudRecoveryService(
            fixture: failedSignature,
            signingVerifier: { _, _ in false }
        ).recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(failedSignatureDidRecover)
        try assertCloudRecoveryFailureWasReadOnly(failedSignature)
    }

    func testCloudRecoveryRejectsRawJsonBackupWithoutWalletMutation() async throws {
        let fixture = try makeCloudRecoveryFixture()
        fixture.cloud.mobileImportResult = OpenBackupAccount(
            name: fixture.account.username,
            address: fixture.account.address,
            cryptoType: fixture.account.cryptoType.typeString,
            substrateDerivationPath: "",
            backupAccountType: [.json],
            json: OpenBackupAccount.Json(substrateJson: "{}", ethJson: nil)
        )

        let didRecover = await makeCloudRecoveryService(fixture: fixture)
            .recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(didRecover)
        try assertCloudRecoveryFailureWasReadOnly(fixture)
    }

    func testCloudRecoveryOverlappingCallsCommitOnlyOnceWithoutDeletingSigner() async throws {
        let fixture = try makeCloudRecoveryFixture()
        fixture.cloud.mobileImportDelayNanoseconds = 100_000_000
        let service = makeCloudRecoveryService(fixture: fixture)

        async let firstAttempt = service.recoverAfterLocalAuthentication(
            protectedDataAvailable: true
        )
        try await Task.sleep(nanoseconds: 10_000_000)
        async let overlappingAttempt = service.recoverAfterLocalAuthentication(
            protectedDataAvailable: true
        )
        let results = await [firstAttempt, overlappingAttempt]

        XCTAssertEqual(results.filter { $0 }.count, 1)
        XCTAssertEqual(fixture.cloud.restoreCallsCount, 1)
        XCTAssertEqual(fixture.cloud.mobileImportCallsCount, 1)
        XCTAssertTrue(
            SelectedWalletSettings.hasVerifiedSigningKey(
                keystore: fixture.keychain,
                account: fixture.account
            )
        )
        XCTAssertNil(fixture.settings.bool(for: "walletMigrationRecoveryRequired"))
    }

    func testCloudRecoveryTimeoutFallsBackWithoutWalletMutation() async throws {
        let fixture = try makeCloudRecoveryFixture()
        fixture.cloud.mobileImportDelayNanoseconds = 5_000_000_000
        let start = Date()

        let didRecover = await makeCloudRecoveryService(
            fixture: fixture,
            cloudTimeout: 0.01
        ).recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(didRecover)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        try assertCloudRecoveryFailureWasReadOnly(fixture)
        try await Task.sleep(nanoseconds: 50_000_000)
        try assertCloudRecoveryFailureWasReadOnly(fixture)
    }

    func testCloudRecoveryCommitFailureRollsBackCanonicalTagsAndKeepsMarker() async throws {
        let fixture = try makeCloudRecoveryFixture()
        var verificationCount = 0
        let verifier: RetainedWalletCloudRecoveryService.SigningVerifier = { keystore, account in
            verificationCount += 1
            guard verificationCount == 1 else {
                return false
            }
            return SelectedWalletSettings.hasVerifiedSigningKey(
                keystore: keystore,
                account: account
            )
        }

        let didRecover = await makeCloudRecoveryService(
            fixture: fixture,
            signingVerifier: verifier
        ).recoverAfterLocalAuthentication(protectedDataAvailable: true)
        XCTAssertFalse(didRecover)
        XCTAssertEqual(verificationCount, 2)
        XCTAssertEqual(fixture.settings.mutationCount, 0)
        XCTAssertEqual(
            fixture.settings.bool(for: "walletMigrationRecoveryRequired"),
            true
        )
        XCTAssertFalse(try fixture.keychain.checkSecretKeyForAddress(fixture.account.address))
        XCTAssertFalse(try fixture.keychain.checkSeedForAddress(fixture.account.address))
        XCTAssertFalse(try fixture.keychain.checkEntropyForAddress(fixture.account.address))
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

    private typealias CloudRecoveryFixture = (
        settings: RecordingSettingsManager,
        keychain: RecordingKeystore,
        cloud: RetainedWalletCloudStorageMock,
        account: AccountItem,
        backup: OpenBackupAccount,
        entropy: Data,
        seed: Data,
        secretKey: Data,
        pin: String
    )

    private func makeCloudRecoveryFixture() throws -> CloudRecoveryFixture {
        let entropy = Data((0 ..< 16).map { UInt8($0 + 11) })
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: entropy)
        let local = try makeMnemonicRecoveryFixture(entropy: entropy)
        let settings = RecordingSettingsManager()
        settings.set(value: true, for: "walletMigrationRecoveryRequired")
        settings.set(value: "cloud-recovery", for: "walletMigrationRecoveryReason")
        settings.set(value: local.account, for: SettingsKey.selectedAccount.rawValue)
        settings.set(
            value: local.account,
            for: "walletMigrationRecoveryExpectedAccount"
        )
        settings.resetMutationTracking()

        let pin = "123456"
        let keychain = RecordingKeystore()
        try keychain.addKey(Data(pin.utf8), with: KeystoreTag.pincode.rawValue)
        keychain.resetMutationTracking()

        let backup = OpenBackupAccount(
            name: local.account.username,
            address: local.account.address,
            passphrase: mnemonic.toString(),
            cryptoType: local.account.cryptoType.typeString,
            substrateDerivationPath: "",
            backupAccountType: [.passphrase]
        )
        let cloud = RetainedWalletCloudStorageMock()
        cloud.mobileImportResult = backup

        return (
            settings,
            keychain,
            cloud,
            local.account,
            backup,
            entropy,
            local.seed,
            local.secretKey,
            pin
        )
    }

    private func makeCloudRecoveryService(
        fixture: CloudRecoveryFixture,
        signingVerifier: @escaping RetainedWalletCloudRecoveryService.SigningVerifier = {
            SelectedWalletSettings.hasVerifiedSigningKey(keystore: $0, account: $1)
        },
        materialCandidateProvider: RetainedSigningMaterialCandidateProviding? = nil,
        cloudTimeout: TimeInterval = 1
    ) -> RetainedWalletCloudRecoveryService {
        RetainedWalletCloudRecoveryService(
            settings: fixture.settings,
            keystore: fixture.keychain,
            cloudStorage: fixture.cloud,
            selectedAccountProvider: { fixture.account },
            signingVerifier: signingVerifier,
            materialCandidateProvider: materialCandidateProvider,
            cloudTimeout: cloudTimeout
        )
    }

    private func assertCloudRecoveryFailureWasReadOnly(
        _ fixture: CloudRecoveryFixture,
        expectedMarker: Bool? = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(fixture.settings.mutationCount, 0, file: file, line: line)
        XCTAssertEqual(fixture.keychain.mutationCount, 0, file: file, line: line)
        XCTAssertEqual(
            fixture.settings.bool(for: "walletMigrationRecoveryRequired"),
            expectedMarker,
            file: file,
            line: line
        )
        XCTAssertFalse(
            try fixture.keychain.checkSecretKeyForAddress(fixture.account.address),
            file: file,
            line: line
        )
        XCTAssertFalse(
            try fixture.keychain.checkSeedForAddress(fixture.account.address),
            file: file,
            line: line
        )
        XCTAssertFalse(
            try fixture.keychain.checkEntropyForAddress(fixture.account.address),
            file: file,
            line: line
        )
    }

}

private enum CloudRecoveryTestError: Error {
    case network
}

private final class RetainedWalletCloudStorageMock: CloudStorageServiceProtocol {
    var isUserAuthorized: Bool { restoreState == .authorized }
    var restoreState: CloudStorageAccountState = .authorized
    var restoreError: Error?
    var mobileImportResult: OpenBackupAccount?
    var mobileImportError: Error?
    var mobileImportDelayNanoseconds: UInt64 = 0
    private(set) var restoreCallsCount = 0
    private(set) var mobileImportCallsCount = 0
    private(set) var receivedAddress: String?
    private(set) var receivedPassword: String?

    func restorePreviousSignInIfAvailable() async throws -> CloudStorageAccountState {
        restoreCallsCount += 1
        if let restoreError {
            throw restoreError
        }
        return restoreState
    }

    func importMobileBackupIfAuthorized(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        mobileImportCallsCount += 1
        receivedAddress = account.address
        receivedPassword = password
        if mobileImportDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: mobileImportDelayNanoseconds)
        }
        if let mobileImportError {
            throw mobileImportError
        }
        guard let mobileImportResult else {
            throw CloudStorageServiceError.notFound
        }
        return mobileImportResult
    }

    func signInIfNeeded() async throws -> CloudStorageAccountState { .notAuthorized }
    func getBackupAccounts() async throws -> [OpenBackupAccount] { [] }
    func saveBackup(account: OpenBackupAccount, password: String) async throws {}
    func importBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        try await importMobileBackupIfAuthorized(account: account, password: password)
    }
    func deleteBackup(account: OpenBackupAccount) async throws {}
    func disconnect() {}
}

private final class RetainedSigningMaterialCandidateProviderMock:
    RetainedSigningMaterialCandidateProviding
{
    let candidates: [Data]
    private(set) var loadCallCount = 0
    private(set) var wasCalledOnMainThread = false

    init(candidates: [Data]) {
        self.candidates = candidates
    }

    func loadAccessibleSigningMaterialCandidates() -> [Data] {
        loadCallCount += 1
        wasCalledOnMainThread = Thread.isMainThread
        return candidates
    }
}

private final class RecordingKeystore: KeystoreProtocol {
    private let storage = InMemoryKeychain()
    private(set) var mutationCount = 0

    func resetMutationTracking() {
        mutationCount = 0
    }

    func addKey(_ key: Data, with identifier: String) throws {
        mutationCount += 1
        try storage.addKey(key, with: identifier)
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        mutationCount += 1
        try storage.updateKey(key, with: identifier)
    }

    func fetchKey(for identifier: String) throws -> Data {
        try storage.fetchKey(for: identifier)
    }

    func checkKey(for identifier: String) throws -> Bool {
        try storage.checkKey(for: identifier)
    }

    func deleteKey(for identifier: String) throws {
        mutationCount += 1
        try storage.deleteKey(for: identifier)
    }
}

private final class ChangingSecretKeystore: KeystoreProtocol {
    private var storage: [String: Data]
    private let targetIdentifier: String
    private let replacementValue: Data
    private(set) var targetFetchCount = 0

    init(identifier: String, initialValue: Data, replacementValue: Data) {
        targetIdentifier = identifier
        storage = [identifier: initialValue]
        self.replacementValue = replacementValue
    }

    func addKey(_ key: Data, with identifier: String) throws {
        guard storage[identifier] == nil else {
            throw KeystoreError.duplicatedItem
        }
        storage[identifier] = key
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        guard storage[identifier] != nil else {
            throw KeystoreError.noKeyFound
        }
        storage[identifier] = key
    }

    func fetchKey(for identifier: String) throws -> Data {
        guard let value = storage[identifier] else {
            throw KeystoreError.noKeyFound
        }
        guard identifier == targetIdentifier else {
            return value
        }

        targetFetchCount += 1
        return targetFetchCount == 1 ? value : replacementValue
    }

    func checkKey(for identifier: String) throws -> Bool {
        storage[identifier] != nil
    }

    func deleteKey(for identifier: String) throws {
        guard storage.removeValue(forKey: identifier) != nil else {
            throw KeystoreError.noKeyFound
        }
    }
}

private final class RecordingSettingsManager: SettingsManagerProtocol {
    private let storage = InMemorySettingsManager()
    private(set) var mutationCount = 0
    private(set) var removedKeys: [String] = []

    func resetMutationTracking() {
        mutationCount = 0
        removedKeys = []
    }

    func set(value: Bool, for key: String) {
        mutationCount += 1
        storage.set(value: value, for: key)
    }

    func set(value: Int, for key: String) {
        mutationCount += 1
        storage.set(value: value, for: key)
    }

    func set(value: Double, for key: String) {
        mutationCount += 1
        storage.set(value: value, for: key)
    }

    func set(value: String, for key: String) {
        mutationCount += 1
        storage.set(value: value, for: key)
    }

    func set(value: Data, for key: String) {
        mutationCount += 1
        storage.set(value: value, for: key)
    }

    func set(anyValue: Any, for key: String) {
        mutationCount += 1
        storage.set(anyValue: anyValue, for: key)
    }

    func bool(for key: String) -> Bool? { storage.bool(for: key) }
    func integer(for key: String) -> Int? { storage.integer(for: key) }
    func double(for key: String) -> Double? { storage.double(for: key) }
    func string(for key: String) -> String? { storage.string(for: key) }
    func data(for key: String) -> Data? { storage.data(for: key) }
    func anyValue(for key: String) -> Any? { storage.anyValue(for: key) }

    func removeValue(for key: String) {
        mutationCount += 1
        removedKeys.append(key)
        storage.removeValue(for: key)
    }

    func removeAll() {
        mutationCount += 1
        storage.removeAll()
    }
}
