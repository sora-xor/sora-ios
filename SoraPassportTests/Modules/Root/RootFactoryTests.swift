import XCTest
import UIKit
@testable import SoraPassport
import SoraKeystore
import IrohaCrypto
import SSFUtils
import SSFCrypto
import SSFCloudStorage
import RobinHood
import SoraFoundation

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

    @MainActor
    func testRecoveryPresentationWaitsForSigningAlertDismissal() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        let alert = UIAlertController(
            title: "Wallet signing unavailable",
            message: nil,
            preferredStyle: .alert
        )
        let presented = expectation(description: "recovery presentation scheduled")

        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.present(alert, animated: false)
        XCTAssertTrue(controller.presentedViewController === alert)

        XCTAssertTrue(
            MainTabBarViewFactory.presentAfterDismissingAlert(from: controller) {
                XCTAssertNil(controller.presentedViewController)
                presented.fulfill()
            }
        )

        wait(for: [presented], timeout: 2)
        window.isHidden = true
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
    func testRecoveryBannerLeavesBrowseInteractionsEnabled() throws {
        let controller = MainTabBarViewController()
        controller.recoveryRequiredProvider = { true }
        let wallet = UIViewController()
        let activity = UIViewController()
        controller.viewControllers = [wallet, activity]
        controller.loadViewIfNeeded()
        controller.selectedIndex = 1
        controller.enableRecoveryReadOnlyMode()
        controller.view.layoutIfNeeded()

        let banner = try XCTUnwrap(controller.recoveryInteractionShield)
        XCTAssertEqual(controller.selectedIndex, 1)
        XCTAssertTrue(banner.isUserInteractionEnabled)
        XCTAssertTrue(banner.isDescendant(of: controller.view))
        XCTAssertLessThan(banner.bounds.height, controller.view.bounds.height)
        XCTAssertFalse(wallet.view.accessibilityElementsHidden)
        XCTAssertFalse(activity.view.accessibilityElementsHidden)
        XCTAssertFalse(controller.tabBar.accessibilityElementsHidden)
        XCTAssertFalse(banner.accessibilityViewIsModal)
        XCTAssertGreaterThan(controller.additionalSafeAreaInsets.top, 0)
        XCTAssertLessThanOrEqual(
            banner.frame.maxY,
            controller.view.safeAreaInsets.top + 1
        )
    }

    @MainActor
    func testRecoveryBannerRestoreButtonInvokesHandler() throws {
        let controller = MainTabBarViewController()
        controller.recoveryRequiredProvider = { true }
        controller.viewControllers = [UIViewController()]
        var invocationCount = 0
        controller.recoveryRestoreHandler = { invocationCount += 1 }
        controller.loadViewIfNeeded()
        controller.enableRecoveryReadOnlyMode()

        let banner = try XCTUnwrap(controller.recoveryInteractionShield)
        let restoreButton = try XCTUnwrap(banner.subviews.compactMap { $0 as? UIButton }.first)
        restoreButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(invocationCount, 1)
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

        try keychain.saveSecretKey(
            Data(repeating: 0xff, count: 64),
            address: account.address
        )
        XCTAssertFalse(
            AddAccountImportInteractor.isValidRecoveryReplacement(
                account,
                expected: account,
                existing: account,
                keystore: keychain
            )
        )
    }

    func testRecoveryImportPreservesRetainedWalletMetadata() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map(UInt8.init))
        )
        let retained = AccountItem(
            address: fixture.account.address,
            cryptoType: fixture.account.cryptoType,
            networkType: fixture.account.networkType,
            username: "old name",
            publicKeyData: fixture.account.publicKeyData,
            settings: AccountSettings(
                visibleAssetIds: ["xor", "val"],
                orderedAssetIds: ["val", "xor"]
            ),
            order: 7,
            isSelected: true
        )
        let candidate = AccountItem(
            address: retained.address,
            cryptoType: retained.cryptoType,
            networkType: retained.networkType,
            username: "restored name",
            publicKeyData: retained.publicKeyData,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
            order: 0,
            isSelected: true
        )

        let recovered = AddAccountImportInteractor.recoveredAccount(
            existing: retained,
            candidate: candidate
        )

        XCTAssertEqual(recovered.username, candidate.username)
        XCTAssertEqual(recovered.settings, retained.settings)
        XCTAssertEqual(recovered.order, retained.order)
        XCTAssertEqual(recovered.isSelected, retained.isSelected)
    }

    func testMismatchedJsonCannotOverwriteRetainedSigner() throws {
        let retainedKeypair = try SNKeyFactory().createKeypair(
            fromSeed: Data(repeating: 21, count: 32)
        )
        let importedKeypair = try SNKeyFactory().createKeypair(
            fromSeed: Data(repeating: 22, count: 32)
        )
        let retainedPublicKey = retainedKeypair.publicKey().rawData()
        let retainedAddress = try SS58AddressFactory().address(
            fromAccountId: retainedPublicKey,
            type: ApplicationConfig.shared.addressType
        )
        let encoded = KeystoreConstants.pkcs8Header
            + importedKeypair.privateKey().toEd25519Data()
            + KeystoreConstants.pkcs8Divider
            + retainedPublicKey
        let definition = KeystoreDefinition(
            address: retainedAddress,
            encoded: encoded.base64EncodedString(),
            encoding: KeystoreEncoding(
                content: ["pkcs8", "sr25519"],
                type: [],
                version: "3"
            ),
            meta: nil
        )
        let json = try JSONEncoder().encode(definition)
        let jsonString = try XCTUnwrap(String(data: json, encoding: .utf8))
        let keychain = InMemoryKeychain()
        let retainedSecret = retainedKeypair.privateKey().rawData()
        try keychain.saveSecretKey(retainedSecret, address: retainedAddress)
        let operation = AccountOperationFactory(keystore: keychain)
            .newAccountOperation(
                request: AccountImportKeystoreRequest(
                    keystore: jsonString,
                    password: "",
                    username: "mismatched",
                    networkType: .sora,
                    cryptoType: .sr25519
                )
            )

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        XCTAssertThrowsError(
            try operation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(retainedAddress),
            retainedSecret
        )

        let malformedEncoded = KeystoreConstants.pkcs8Header
            + Data(repeating: 0xff, count: 64)
            + KeystoreConstants.pkcs8Divider
            + retainedPublicKey
        let malformedDefinition = KeystoreDefinition(
            address: retainedAddress,
            encoded: malformedEncoded.base64EncodedString(),
            encoding: KeystoreEncoding(
                content: ["pkcs8", "sr25519"],
                type: [],
                version: "3"
            ),
            meta: nil
        )
        let malformedJSON = try JSONEncoder().encode(malformedDefinition)
        let malformedJSONString = try XCTUnwrap(
            String(data: malformedJSON, encoding: .utf8)
        )
        let malformedOperation = AccountOperationFactory(keystore: keychain)
            .newAccountOperation(
                request: AccountImportKeystoreRequest(
                    keystore: malformedJSONString,
                    password: "",
                    username: "malformed",
                    networkType: .sora,
                    cryptoType: .sr25519
                )
            )

        OperationQueue().addOperations(
            [malformedOperation],
            waitUntilFinished: true
        )

        XCTAssertThrowsError(
            try malformedOperation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(retainedAddress),
            retainedSecret
        )
    }

    func testRecoveryIdentityReachesFinalImportStep() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map(UInt8.init))
        )
        let existingURLHandlers = URLHandlingService.shared.children
        URLHandlingService.shared.setup(
            children: [KeystoreImportService(logger: Logger.shared)]
        )
        defer {
            URLHandlingService.shared.setup(children: existingURLHandlers)
        }

        let initialView = try XCTUnwrap(
            AccountImportViewFactory.createViewForAdding(
                sourceType: .mnemonic,
                endAddingBlock: {},
                recoveryAccount: fixture.account
            ) as? ImportAccountViewController
        )
        let initialPresenter = try XCTUnwrap(
            initialView.presenter as? AccountImportPresenter
        )
        let recoveryWireframe = try XCTUnwrap(
            initialPresenter.wireframe as? AddImportedWireframe
        )
        XCTAssertEqual(
            recoveryWireframe.recoveryAccount?.address,
            fixture.account.address
        )
        XCTAssertEqual(initialPresenter.selectedSourceType, .mnemonic)
        XCTAssertEqual(initialPresenter.selectedCryptoType, fixture.account.cryptoType)
        XCTAssertEqual(initialPresenter.selectedNetworkType, fixture.account.networkType.chain)
        XCTAssertTrue(initialPresenter.recoveryMode)

        let sourceViewModel = InputViewModel(
            inputHandler: InputHandler(value: "source")
        )
        let usernameViewModel = InputViewModel(
            inputHandler: InputHandler(value: "retained")
        )
        let view = try XCTUnwrap(
            SetupAccountNameViewFactory.createViewForAddImport(
                sourceType: .mnemonic,
                cryptoType: fixture.account.cryptoType,
                networkType: .sora,
                sourceViewModel: sourceViewModel,
                usernameViewModel: usernameViewModel,
                passwordViewModel: nil,
                derivationPathViewModel: nil,
                endAddingBlock: nil,
                recoveryAccount: fixture.account
            ) as? SetupAccountNameViewController
        )
        let presenter = try XCTUnwrap(
            view.presenter as? SetupNameImportAccountPresenter
        )
        let interactor = try XCTUnwrap(
            presenter.interactor as? AddAccountImportInteractor
        )

        XCTAssertEqual(interactor.recoveryAccount?.address, fixture.account.address)
        XCTAssertEqual(
            interactor.recoveryAccount?.publicKeyData,
            fixture.account.publicKeyData
        )
    }

    @MainActor
    func testRecoveryPresenterImportsEachSourceDirectlyAndCompletesOnce() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map(UInt8.init))
        )

        for sourceType in AccountImportSource.allCases {
            var completionCount = 0
            let view = RecoveryAccountImportViewSpy()
            let interactor = RecoveryAccountImportInteractorSpy()
            let presenter = AccountImportPresenter(
                sourceType: sourceType,
                config: ApplicationConfig.shared,
                recoveryMode: true,
                recoveryAccount: fixture.account,
                recoveryCompletion: { completionCount += 1 }
            )
            presenter.view = view
            presenter.interactor = interactor
            presenter.wireframe = AddImportedWireframe(
                localizationManager: LocalizationManager.shared,
                recoveryAccount: fixture.account
            )
            presenter.localizationManager = LocalizationManager.shared
            interactor.presenter = presenter
            presenter.setup()

            switch sourceType {
            case .mnemonic:
                presenter.sourceViewModel?.inputHandler.changeValue(to: "one two three")
            case .seed:
                presenter.sourceViewModel?.inputHandler.changeValue(
                    to: String(repeating: "a", count: 64)
                )
            case .keystore:
                presenter.sourceViewModel?.inputHandler.changeValue(to: "{}")
                presenter.passwordViewModel?.inputHandler.changeValue(to: "backup-password")
            }

            presenter.proceed()

            XCTAssertEqual(view.loadingStates, [true], "source: \(sourceType)")
            XCTAssertEqual(interactor.totalImportCount, 1, "source: \(sourceType)")
            XCTAssertEqual(interactor.lastImportedSource, sourceType)

            switch sourceType {
            case .mnemonic:
                let request = try XCTUnwrap(interactor.mnemonicRequests.first)
                XCTAssertEqual(request.mnemonic, "one two three")
                XCTAssertEqual(request.username, fixture.account.username)
                XCTAssertEqual(request.networkType, fixture.account.networkType.chain)
                XCTAssertEqual(request.cryptoType, fixture.account.cryptoType)
            case .seed:
                let request = try XCTUnwrap(interactor.seedRequests.first)
                XCTAssertEqual(request.seed, String(repeating: "a", count: 64))
                XCTAssertEqual(request.username, fixture.account.username)
                XCTAssertEqual(request.networkType, fixture.account.networkType.chain)
                XCTAssertEqual(request.cryptoType, fixture.account.cryptoType)
            case .keystore:
                let request = try XCTUnwrap(interactor.keystoreRequests.first)
                XCTAssertEqual(request.keystore, "{}")
                XCTAssertEqual(request.password, "backup-password")
                XCTAssertEqual(request.username, fixture.account.username)
                XCTAssertEqual(request.networkType, fixture.account.networkType.chain)
                XCTAssertEqual(request.cryptoType, fixture.account.cryptoType)
            }

            presenter.didCompleteAccountImport()
            presenter.didCompleteAccountImport()

            XCTAssertEqual(view.loadingStates, [true, false], "source: \(sourceType)")
            XCTAssertEqual(view.dismissCount, 1, "source: \(sourceType)")
            XCTAssertEqual(completionCount, 1, "source: \(sourceType)")
        }
    }

    @MainActor
    func testRecoveryChooserShowsAllMethodsForExactWallet() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map(UInt8.init))
        )
        let controller = RetainedWalletRecoveryViewController(account: fixture.account)
        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.account.address, fixture.account.address)
        XCTAssertEqual(controller.methodControls.count, 4)
        XCTAssertEqual(Set(controller.methodControls.map(\.methodTitle)).count, 4)
        XCTAssertTrue(controller.methodControls.allSatisfy(\.isAccessibilityElement))

        XCTAssertTrue(controller.beginMethodSelection())
        XCTAssertFalse(controller.beginMethodSelection())
        XCTAssertTrue(controller.methodControls.allSatisfy { !$0.isEnabled })

        controller.endMethodSelection()
        XCTAssertTrue(controller.methodControls.allSatisfy(\.isEnabled))
    }

    @MainActor
    func testRecoveryJsonFormBindsPasswordAndExactIdentity() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map(UInt8.init))
        )
        let existingURLHandlers = URLHandlingService.shared.children
        URLHandlingService.shared.setup(
            children: [KeystoreImportService(logger: Logger.shared)]
        )
        defer {
            URLHandlingService.shared.setup(children: existingURLHandlers)
        }

        let view = try XCTUnwrap(
            AccountImportViewFactory.createViewForAdding(
                sourceType: .keystore,
                endAddingBlock: {},
                recoveryAccount: fixture.account
            ) as? ImportAccountViewController
        )
        view.loadViewIfNeeded()
        let presenter = try XCTUnwrap(view.presenter as? AccountImportPresenter)
        let suggestedJSON = "{\"address\":\"\(fixture.account.address)\"}"
        presenter.didSuggestKeystore(text: suggestedJSON, preferredInfo: nil)

        XCTAssertTrue(view.isRecoveryMode)
        XCTAssertEqual(view.recoveryAccount?.address, fixture.account.address)
        XCTAssertEqual(view.displayedSourceType, .keystore)
        XCTAssertFalse(view.passwordField.sora.isHidden)
        XCTAssertTrue(view.sourceTextView.isScrollEnabled)
        XCTAssertEqual(view.sourceTextView.text, suggestedJSON)
        XCTAssertEqual(presenter.sourceViewModel?.inputHandler.value, suggestedJSON)
        XCTAssertEqual(presenter.selectedCryptoType, fixture.account.cryptoType)
        XCTAssertEqual(presenter.selectedNetworkType, fixture.account.networkType.chain)
        XCTAssertEqual(presenter.usernameViewModel?.inputHandler.value, fixture.account.username)
    }

    func testRecoveryCloudPasswordErrorsAreActionable() {
        XCTAssertEqual(
            EnterPasswordViewModel.classify(error: CloudStorageServiceError.incorectPassword),
            .incorrectPassword
        )
        XCTAssertEqual(
            EnterPasswordViewModel.classify(error: CloudStorageServiceError.notFound),
            .backupNotFound
        )
        XCTAssertEqual(
            EnterPasswordViewModel.classify(error: CloudStorageServiceError.notAuthorized),
            .authorization
        )
        XCTAssertEqual(
            EnterPasswordViewModel.classify(error: CloudStorageServiceError.incorectJson),
            .unreadableBackup
        )
        XCTAssertEqual(
            EnterPasswordViewModel.classify(error: AccountCreateError.invalidSeed),
            .differentWallet
        )
        XCTAssertNotNil(
            AccountImportPresenter.recoveryErrorMessage(for: AccountCreateError.invalidSeed)
        )
    }

    @MainActor
    func testRecoveryPasteNormalizesAndRejectsWrongSourceShape() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map(UInt8.init))
        )
        let existingURLHandlers = URLHandlingService.shared.children
        URLHandlingService.shared.setup(
            children: [KeystoreImportService(logger: Logger.shared)]
        )
        defer {
            URLHandlingService.shared.setup(children: existingURLHandlers)
        }

        let view = try XCTUnwrap(
            AccountImportViewFactory.createViewForAdding(
                sourceType: .seed,
                endAddingBlock: {},
                recoveryAccount: fixture.account
            ) as? ImportAccountViewController
        )
        view.loadViewIfNeeded()

        let seed = String(repeating: "a", count: 64)
        XCTAssertTrue(view.applyPastedSource("  \(seed)\n"))
        XCTAssertEqual(view.sourceTextView.text, seed)
        XCTAssertFalse(view.applyPastedSource("not-a-seed\n"))
        XCTAssertEqual(view.sourceTextView.text, seed)

        XCTAssertEqual(
            ImportAccountViewController.normalizedPastedSource(
                "  one   two\nthree  ",
                sourceType: .mnemonic
            ),
            "one two three"
        )
    }

    @MainActor
    func testRecoveryVerificationLocksBackNavigationUntilItFinishes() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 16).map(UInt8.init))
        )
        let existingURLHandlers = URLHandlingService.shared.children
        URLHandlingService.shared.setup(
            children: [KeystoreImportService(logger: Logger.shared)]
        )
        defer {
            URLHandlingService.shared.setup(children: existingURLHandlers)
        }

        let root = UIViewController()
        let importView = try XCTUnwrap(
            AccountImportViewFactory.createViewForAdding(
                sourceType: .mnemonic,
                endAddingBlock: {},
                recoveryAccount: fixture.account
            ) as? ImportAccountViewController
        )
        let navigationController = SoraNavigationController(rootViewController: root)
        navigationController.pushViewController(importView, animated: false)
        navigationController.loadViewIfNeeded()
        importView.loadViewIfNeeded()

        let originalPopState = navigationController.interactivePopGestureRecognizer?.isEnabled
        importView.setLoading(true)

        XCTAssertTrue(navigationController.isModalInPresentation)
        XCTAssertTrue(importView.navigationItem.hidesBackButton)
        XCTAssertEqual(navigationController.interactivePopGestureRecognizer?.isEnabled, false)

        importView.setLoading(false)

        XCTAssertFalse(navigationController.isModalInPresentation)
        XCTAssertFalse(importView.navigationItem.hidesBackButton)
        XCTAssertEqual(
            navigationController.interactivePopGestureRecognizer?.isEnabled,
            originalPopState
        )
    }

    @MainActor
    func testRecoveryCloudVerificationLocksBackNavigationUntilItFinishes() {
        let root = UIViewController()
        let passwordView = EnterPasswordViewController()
        let navigationController = SoraNavigationController(rootViewController: root)
        navigationController.pushViewController(passwordView, animated: false)
        navigationController.loadViewIfNeeded()
        passwordView.loadViewIfNeeded()

        let originalPopState = navigationController.interactivePopGestureRecognizer?.isEnabled
        passwordView.showLoading()

        XCTAssertTrue(navigationController.isModalInPresentation)
        XCTAssertTrue(passwordView.navigationItem.hidesBackButton)
        XCTAssertEqual(navigationController.interactivePopGestureRecognizer?.isEnabled, false)

        passwordView.hideLoading()

        XCTAssertFalse(navigationController.isModalInPresentation)
        XCTAssertFalse(passwordView.navigationItem.hidesBackButton)
        XCTAssertEqual(
            navigationController.interactivePopGestureRecognizer?.isEnabled,
            originalPopState
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

    func testVerifiedCanonicalSignerCreatesCreateOnlyPreservationRecord() throws {
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 41) })
        )
        try keychain.saveSecretKey(fixture.secretKey, address: fixture.account.address)

        XCTAssertTrue(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchPreservedSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )

        let conflicting = Data(repeating: 0xff, count: fixture.secretKey.count)
        try keychain.updateKey(
            conflicting,
            with: KeystoreTag.preservedSecretKeyTagForAddress(fixture.account.address)
        )
        XCTAssertTrue(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchPreservedSecretKeyForAddress(fixture.account.address),
            conflicting,
            "An existing preservation record must never be overwritten"
        )
    }

    func testMissingCanonicalSignerSelfHealsOnlyFromExactPreservedIdentity() throws {
        let keychain = InMemoryKeychain()
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 47) })
        )
        try keychain.addKey(
            fixture.secretKey,
            with: KeystoreTag.preservedSecretKeyTagForAddress(fixture.account.address)
        )

        XCTAssertTrue(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: fixture.account
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
    }

    func testEd25519SignerIsPreservedAndRestoredWithExactIdentity() throws {
        let keychain = InMemoryKeychain()
        let fixture = try makeRawSeedRecoveryFixture(
            seed: Data((0 ..< 32).map { UInt8($0 + 83) })
        )
        try keychain.saveSecretKey(fixture.secretKey, address: fixture.account.address)

        XCTAssertTrue(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: fixture.account
            )
        )
        try keychain.deleteKey(
            for: KeystoreTag.secretKeyTagForAddress(fixture.account.address)
        )
        XCTAssertTrue(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
    }

    func testEcdsaSignerIsPreservedAndRestoredWithExactIdentity() throws {
        let keychain = InMemoryKeychain()
        let fixture = try makeEcdsaRecoveryFixture(
            seed: Data((0 ..< 32).map { UInt8($0 + 131) })
        )
        try keychain.saveSecretKey(fixture.secretKey, address: fixture.account.address)

        XCTAssertTrue(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: fixture.account
            )
        )
        try keychain.deleteKey(
            for: KeystoreTag.secretKeyTagForAddress(fixture.account.address)
        )
        XCTAssertTrue(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: fixture.account
            )
        )
        XCTAssertEqual(
            try keychain.fetchSecretKeyForAddress(fixture.account.address),
            fixture.secretKey
        )
    }

    func testSelectedAndUnselectedPersistedAccountsBothReceivePreservationRecords() throws {
        let keychain = InMemoryKeychain()
        let selected = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 89) })
        )
        let unselectedFixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 97) })
        )
        let unselected = AccountItem(
            address: unselectedFixture.account.address,
            cryptoType: unselectedFixture.account.cryptoType,
            networkType: unselectedFixture.account.networkType,
            username: unselectedFixture.account.username,
            publicKeyData: unselectedFixture.account.publicKeyData,
            settings: unselectedFixture.account.settings,
            order: 1,
            isSelected: false
        )
        try keychain.saveSecretKey(selected.secretKey, address: selected.account.address)
        try keychain.saveSecretKey(unselectedFixture.secretKey, address: unselected.address)

        SelectedWalletSettings.reconcileSigningKeyPreservations(
            keystore: keychain,
            accounts: [selected.account, unselected]
        )

        XCTAssertEqual(
            try keychain.fetchPreservedSecretKeyForAddress(selected.account.address),
            selected.secretKey
        )
        XCTAssertEqual(
            try keychain.fetchPreservedSecretKeyForAddress(unselected.address),
            unselectedFixture.secretKey
        )
    }

    func testPreservedSignerForDifferentIdentityNeverMutatesCanonicalTag() throws {
        let keychain = InMemoryKeychain()
        let expected = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 53) })
        )
        let different = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 59) })
        )
        try keychain.addKey(
            different.secretKey,
            with: KeystoreTag.preservedSecretKeyTagForAddress(expected.account.address)
        )

        XCTAssertFalse(
            try SelectedWalletSettings.reconcileSigningKeyPreservation(
                keystore: keychain,
                account: expected.account
            )
        )
        XCTAssertNil(try keychain.fetchSecretKeyForAddress(expected.account.address))
        XCTAssertEqual(
            try keychain.fetchPreservedSecretKeyForAddress(expected.account.address),
            different.secretKey
        )
    }

    func testExplicitAccountKeyDeletionRemovesPreservationWithoutDeletingPin() throws {
        let keychain = InMemoryKeychain()
        let entropy = Data((0 ..< 20).map { UInt8($0 + 61) })
        let fixture = try makeMnemonicRecoveryFixture(entropy: entropy)
        try keychain.saveKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        try keychain.saveSecretKey(fixture.secretKey, address: fixture.account.address)
        try keychain.addKey(
            fixture.secretKey,
            with: KeystoreTag.preservedSecretKeyTagForAddress(fixture.account.address)
        )
        try keychain.saveSeed(fixture.seed, address: fixture.account.address)
        try keychain.saveEntropy(entropy, address: fixture.account.address)

        try keychain.deleteAccountKeys(for: fixture.account.address)

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTag.pincode.rawValue))
        XCTAssertNil(try keychain.fetchSecretKeyForAddress(fixture.account.address))
        XCTAssertNil(try keychain.fetchPreservedSecretKeyForAddress(fixture.account.address))
        XCTAssertNil(try keychain.fetchSeedForAddress(fixture.account.address))
        XCTAssertNil(try keychain.fetchEntropyForAddress(fixture.account.address))
    }

    func testFailedAccountDeletionOrFollowUpNeverDeletesSignerCopies() throws {
        let fixture = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 103) })
        )

        for failurePoint in 0 ..< 2 {
            let keychain = InMemoryKeychain()
            try keychain.saveSecretKey(fixture.secretKey, address: fixture.account.address)
            try keychain.addKey(
                fixture.secretKey,
                with: KeystoreTag.preservedSecretKeyTagForAddress(fixture.account.address)
            )
            let forgetOperation = BaseOperation<Void>()
            let countOperation = BaseOperation<[AccountItem]>()
            forgetOperation.result = failurePoint == 0
                ? .failure(CloudRecoveryTestError.network)
                : .success(())
            countOperation.result = failurePoint == 1
                ? .failure(CloudRecoveryTestError.network)
                : .success([])

            XCTAssertNil(
                AccountOptionsInteractor.deleteWalletMaterialAfterSuccessfulAccountDeletion(
                    forgetOperation: forgetOperation,
                    countOperation: countOperation,
                    keystore: keychain,
                    address: fixture.account.address
                )
            )
            XCTAssertEqual(
                try keychain.fetchSecretKeyForAddress(fixture.account.address),
                fixture.secretKey
            )
            XCTAssertEqual(
                try keychain.fetchPreservedSecretKeyForAddress(fixture.account.address),
                fixture.secretKey
            )
        }
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

    func testInteractiveRecoveryUsesExactMobileBackupWithoutBroadFallback() async throws {
        let fixture = try makeCloudRecoveryFixture()
        fixture.cloud.interactiveSignInState = .authorized
        fixture.cloud.mobileImportResult = fixture.backup
        let request = AccountImportBackedupRequest(
            account: OpenBackupAccount(address: fixture.account.address),
            password: fixture.pin
        )

        let restored = try await BaseAccountImportInteractor.fetchBackedUpAccount(
            cloudStorage: fixture.cloud,
            request: request,
            exactMobileBackupOnly: true
        )

        XCTAssertEqual(restored.address, fixture.account.address)
        XCTAssertEqual(fixture.cloud.interactiveSignInCallsCount, 1)
        XCTAssertEqual(fixture.cloud.mobileImportCallsCount, 1)
        XCTAssertEqual(fixture.cloud.broadImportCallsCount, 0)
    }

    func testRecoveryIdentityComparisonRejectsDifferentPublicKey() throws {
        let expected = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 67) })
        ).account
        let different = try makeMnemonicRecoveryFixture(
            entropy: Data((0 ..< 20).map { UInt8($0 + 73) })
        ).account

        XCTAssertTrue(MainTabBarViewFactory.sameRecoveryIdentity(expected, expected))
        XCTAssertFalse(MainTabBarViewFactory.sameRecoveryIdentity(expected, different))
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

    private func makeEcdsaRecoveryFixture(
        seed: Data
    ) throws -> (account: AccountItem, secretKey: Data) {
        let factory = EcdsaKeypairFactory()
        let keypair = try factory.createKeypairFromSeed(seed, chaincodeList: [])
        let publicKey = keypair.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: ApplicationConfig.shared.addressType
        )
        let account = AccountItem(
            address: address,
            cryptoType: .ecdsa,
            networkType: ApplicationConfig.shared.addressType,
            username: "ecdsa seed",
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
    var interactiveSignInState: CloudStorageAccountState = .notAuthorized
    private(set) var restoreCallsCount = 0
    private(set) var interactiveSignInCallsCount = 0
    private(set) var mobileImportCallsCount = 0
    private(set) var broadImportCallsCount = 0
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

    func signInIfNeeded() async throws -> CloudStorageAccountState {
        interactiveSignInCallsCount += 1
        return interactiveSignInState
    }
    func getBackupAccounts() async throws -> [OpenBackupAccount] { [] }
    func saveBackup(account: OpenBackupAccount, password: String) async throws {}
    func importBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        broadImportCallsCount += 1
        return try await importMobileBackupIfAuthorized(
            account: account,
            password: password
        )
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

private final class RecoveryAccountImportViewSpy: AccountImportViewProtocol {
    let controller = UIViewController()
    var isSetup: Bool { true }

    private(set) var loadingStates: [Bool] = []
    private(set) var dismissCount = 0

    func setSource(type: AccountImportSource) {}
    func setSource(viewModel: InputViewModelProtocol) {}
    func setName(viewModel: InputViewModelProtocol) {}
    func setPassword(viewModel: InputViewModelProtocol) {}
    func setDerivationPath(viewModel: InputViewModelProtocol) {}
    func setUploadWarning(message: String) {}
    func setRecoveryMode(_ isRecovery: Bool, account: AccountItem?) {}
    func resetFocus() {}

    func setLoading(_ isLoading: Bool) {
        loadingStates.append(isLoading)
    }

    func dismissPresentedController(completion: (() -> Void)?) {
        dismissCount += 1
        completion?()
    }
}

private final class RecoveryAccountImportInteractorSpy: AccountImportInteractorInputProtocol {
    weak var presenter: AccountImportInteractorOutputProtocol?

    private(set) var mnemonicRequests: [AccountImportMnemonicRequest] = []
    private(set) var seedRequests: [AccountImportSeedRequest] = []
    private(set) var keystoreRequests: [AccountImportKeystoreRequest] = []

    var totalImportCount: Int {
        mnemonicRequests.count + seedRequests.count + keystoreRequests.count
    }

    var lastImportedSource: AccountImportSource? {
        if !mnemonicRequests.isEmpty { return .mnemonic }
        if !seedRequests.isEmpty { return .seed }
        if !keystoreRequests.isEmpty { return .keystore }
        return nil
    }

    func setup() {
        presenter?.didReceiveAccountImport(
            metadata: AccountImportMetadata(
                availableSources: AccountImportSource.allCases,
                defaultSource: .mnemonic,
                availableNetworks: [.sora],
                defaultNetwork: .sora,
                availableCryptoTypes: CryptoType.allCases,
                defaultCryptoType: .sr25519
            )
        )
    }

    func importAccountWithMnemonic(
        request: AccountImportMnemonicRequest,
        completion: ((Result<AccountItem, Error>?) -> Void)?
    ) {
        mnemonicRequests.append(request)
    }

    func importAccountWithSeed(
        request: AccountImportSeedRequest,
        completion: ((Result<AccountItem, Error>?) -> Void)?
    ) {
        seedRequests.append(request)
    }

    func importAccountWithKeystore(
        request: AccountImportKeystoreRequest,
        completion: ((Result<AccountItem, Error>?) -> Void)?
    ) {
        keystoreRequests.append(request)
    }

    func validateAccountWithMnemonic(
        request: AccountImportMnemonicRequest,
        completion: ((Result<AccountItem?, Error>?) -> Void)?
    ) {}

    func validateAccountWithSeed(
        request: AccountImportSeedRequest,
        completion: ((Result<AccountItem?, Error>?) -> Void)?
    ) {}

    func validateAccountWithKeystore(
        request: AccountImportKeystoreRequest,
        completion: ((Result<AccountItem?, Error>?) -> Void)?
    ) {}

    func deriveMetadataFromKeystore(_ keystore: String) {}
    func importBackedupAccount(request: AccountImportBackedupRequest) {}
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
