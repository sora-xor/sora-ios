// SPDX-License-Identifier: Apache-2.0
import Foundation
import IrohaCrypto
import SoraFoundation
import UIKit
import XCTest
@testable import SoraPassport

/// Constructs real onboarding routes while keeping all persistence and secret
/// loading actions uninvoked. Import URL routing is isolated and restored.
@MainActor
final class OnboardingFactoryFlowTests: XCTestCase {
    private var children = [URLHandlingServiceProtocol]()
    override func setUp() { super.setUp(); children = URLHandlingService.shared.children; URLHandlingService.shared.setup(children: [KeystoreImportService(logger: Logger.shared)]) }
    override func tearDown() { URLHandlingService.shared.setup(children: children); children = []; super.tearDown() }
    private func value(_ text: String) -> InputViewModel { .init(inputHandler: InputHandler(value: text, required: false, predicate: NSPredicate(value: true))) }
    private func name(_ root: Bool, source: AccountImportSource = .mnemonic, completion: (() -> Void)? = nil) throws -> SetupAccountNameViewController {
        let v = root ? SetupAccountNameViewFactory.createViewForAccountImport(sourceType: source, cryptoType: .sr25519, networkType: .sora, sourceViewModel: value("public input"), usernameViewModel: value("Public name"), passwordViewModel: value("public password"), derivationPathViewModel: value("//fixture"), expectedAddress: "public historical address") : SetupAccountNameViewFactory.createViewForAddImport(sourceType: source, cryptoType: .sr25519, networkType: .sora, sourceViewModel: value("public input"), usernameViewModel: value("Public name"), passwordViewModel: value("public password"), derivationPathViewModel: value("//fixture"), expectedAddress: "public historical address", endAddingBlock: completion)
        return try XCTUnwrap(v as? SetupAccountNameViewController)
    }
    private func importing(_ adding: Bool, source: AccountImportSource) throws -> (ImportAccountViewController, AccountImportPresenter) {
        let v = adding ? AccountImportViewFactory.createViewForRedesignAdding(sourceType: source, endAddingBlock: nil) : AccountImportViewFactory.createViewForOnboardingRedesign(sourceType: source)
        let view = try XCTUnwrap(v as? ImportAccountViewController); let presenter = try XCTUnwrap(view.presenter as? AccountImportPresenter)
        XCTAssertTrue(presenter.view === view); XCTAssertNotNil(presenter.interactor); XCTAssertFalse(view.isViewLoaded)
        return (view, presenter)
    }
    func testOnboardingNameRoutePreservesItsModeAndPresenterBinding() throws {
        let view = try XCTUnwrap(SetupAccountNameViewFactory.createViewForOnboarding(mode: .onboarding) as? SetupAccountNameViewController)
        let presenter = try XCTUnwrap(view.presenter as? UsernameSetupPresenter); XCTAssertTrue(presenter.view === view); XCTAssertEqual(presenter.mode, .onboarding); XCTAssertTrue(presenter.wireframe is UsernameSetupWireframe)
    }
    func testNewWalletNameRouteStartsInCreatingMode() throws {
        let view = try XCTUnwrap(SetupAccountNameViewFactory.createViewForAdding(endEditingBlock: nil) as? SetupAccountNameViewController)
        let presenter = try XCTUnwrap(view.presenter as? UsernameSetupPresenter); XCTAssertEqual(presenter.mode, .creating); XCTAssertTrue(presenter.wireframe is AddUsernameWireframe); XCTAssertTrue(presenter.view === view)
    }
    func testRootNameRoutePreservesMnemonicInputAndDerivation() throws {
        let view = try name(true); let presenter = try XCTUnwrap(view.presenter as? SetupNameImportRootPresenter)
        XCTAssertEqual(presenter.sourceType, .mnemonic); XCTAssertEqual(presenter.sourceViewModel.inputHandler.value, "public input"); XCTAssertEqual(presenter.derivationPathViewModel?.inputHandler.value, "//fixture"); XCTAssertTrue(presenter.interactor is AddAccountImportInteractor); XCTAssertTrue(presenter.view === view)
    }
    func testAdditionalNameRoutePreservesSeedInputAndCryptoType() throws {
        let view = try name(false, source: .seed); let presenter = try XCTUnwrap(view.presenter as? SetupNameImportAccountPresenter)
        XCTAssertEqual(presenter.sourceType, .seed); XCTAssertEqual(presenter.cryptoType, .sr25519); XCTAssertEqual(presenter.sourceViewModel.inputHandler.value, "public input"); XCTAssertTrue(presenter.interactor is AddAccountImportInteractor); XCTAssertTrue(presenter.view === view)
    }
    func testAdditionalNameRoutePreservesKeystorePassword() throws {
        let view = try name(false, source: .keystore); let presenter = try XCTUnwrap(view.presenter as? SetupNameImportAccountPresenter)
        XCTAssertEqual(presenter.passwordViewModel?.inputHandler.value, "public password"); XCTAssertEqual(presenter.usernameViewModel.inputHandler.value, "Public name"); XCTAssertEqual(presenter.networkType, .sora)
    }
    func testAdditionalNameRoutePreservesItsCompletion() throws { var calls = 0; let view = try name(false) { calls += 1 }; let presenter = try XCTUnwrap(view.presenter as? SetupNameImportAccountPresenter); presenter.completion?(); XCTAssertEqual(calls, 1) }
    func testCreationNameRouteBindsTheCreationPresenterAndCompletion() throws {
        var calls = 0; let view = try XCTUnwrap(SetupAccountNameViewFactory.createViewForCreationImport { calls += 1 } as? SetupAccountNameViewController)
        let presenter = try XCTUnwrap(view.presenter as? SetupNameCreateAccountPresenter); XCTAssertTrue(presenter.view === view); XCTAssertTrue(presenter.interactor is AddAccountImportInteractor); presenter.completion?(); XCTAssertEqual(calls, 1)
    }
    func testRootMnemonicImportRouteUsesTheRootInteractor() throws { let (_, p) = try importing(false, source: .mnemonic); XCTAssertEqual(p.selectedSourceType, .mnemonic); XCTAssertTrue(p.interactor is AccountImportInteractor); XCTAssertTrue(p.wireframe is AccountImportWireframe) }
    func testRootSeedImportRoutePreservesTheSourceType() throws { let (_, p) = try importing(false, source: .seed); XCTAssertEqual(p.selectedSourceType, .seed) }
    func testRootKeystoreImportRoutePreservesTheSourceType() throws { let (_, p) = try importing(false, source: .keystore); XCTAssertEqual(p.selectedSourceType, .keystore) }
    func testAdditionalMnemonicImportRouteUsesTheAdditionalAccountInteractor() throws { let (_, p) = try importing(true, source: .mnemonic); XCTAssertEqual(p.selectedSourceType, .mnemonic); XCTAssertTrue(p.interactor is AddAccountImportInteractor); XCTAssertTrue(p.wireframe is AddImportedWireframe) }
    func testAdditionalSeedImportRoutePreservesTheSourceType() throws { let (_, p) = try importing(true, source: .seed); XCTAssertEqual(p.selectedSourceType, .seed) }
    func testAdditionalKeystoreImportRoutePreservesTheSourceType() throws { let (_, p) = try importing(true, source: .keystore); XCTAssertEqual(p.selectedSourceType, .keystore) }
    func testGenericAdditionalImportRoutePreservesItsCompletion() throws {
        var calls = 0; let view = try XCTUnwrap(AccountImportViewFactory.createViewForAdding { calls += 1 } as? ImportAccountViewController)
        let p = try XCTUnwrap(view.presenter as? AccountImportPresenter); let route = try XCTUnwrap(p.wireframe as? AddImportedWireframe); route.endAddingBlock?(); XCTAssertEqual(calls, 1); XCTAssertTrue(p.view === view)
    }
    func testImportCannotBeConstructedWithoutTheKeystoreImportService() {
        URLHandlingService.shared.setup(children: [])
        XCTAssertNil(AccountImportViewFactory.createViewForOnboardingRedesign(sourceType: .mnemonic)); XCTAssertNil(AccountImportViewFactory.createViewForAdding(endAddingBlock: nil)); XCTAssertNil(AccountImportViewFactory.createViewForRedesignAdding(sourceType: .seed, endAddingBlock: nil))
    }
    func testNameImportCannotBeConstructedWithoutTheKeystoreImportService() {
        URLHandlingService.shared.setup(children: [])
        XCTAssertNil(SetupAccountNameViewFactory.createViewForAccountImport(sourceType: .mnemonic, cryptoType: .sr25519, networkType: .sora, sourceViewModel: value("input"), usernameViewModel: value("name"), passwordViewModel: nil, derivationPathViewModel: nil))
        XCTAssertNil(SetupAccountNameViewFactory.createViewForAddImport(sourceType: .seed, cryptoType: .sr25519, networkType: .sora, sourceViewModel: value("input"), usernameViewModel: value("name"), passwordViewModel: nil, derivationPathViewModel: nil, endAddingBlock: nil))
        XCTAssertNil(SetupAccountNameViewFactory.createViewForCreationImport(endAddingBlock: nil))
    }
    func testCreationFactoryBindsTheRequestedUsernameWithoutLoadingSecrets() throws {
        let view = try XCTUnwrap(AccountCreateViewFactory.createViewForCreateAccount(username: "New fixture", endAddingBlock: nil) as? AccountCreateViewController)
        let presenter = try XCTUnwrap(view.presenter as? AccountCreatePresenter); XCTAssertEqual(presenter.username, "New fixture"); XCTAssertTrue(presenter.view === view); XCTAssertTrue(presenter.interactor is AccountCreateInteractor); XCTAssertFalse(view.isViewLoaded)
    }
    func testLocalBackupChoiceUsesTheLocalRegistrationScreen() throws {
        let view = try XCTUnwrap(AccountCreateViewFactory.createViewForImportAccount(username: "Local fixture", isGoogleBackupSelected: false, isNeedSetupName: false, endAddingBlock: nil) as? AccountCreateViewController)
        XCTAssertEqual(view.mode, .registrationWithoutAccessToGoogle); XCTAssertEqual((view.presenter as? AccountCreatePresenter)?.username, "Local fixture")
    }
    func testGoogleBackupChoiceUsesTheCloudRegistrationScreen() throws {
        let view = try XCTUnwrap(AccountCreateViewFactory.createViewForImportAccount(username: "Cloud fixture", isGoogleBackupSelected: true, isNeedSetupName: true, endAddingBlock: nil) as? AccountCreateViewController)
        XCTAssertEqual(view.mode, .registration); XCTAssertEqual((view.presenter as? AccountCreatePresenter)?.username, "Cloud fixture")
    }
    func testBackupFactoryUsesTheRequestedAccountInReadOnlyMode() throws {
        let key = Data(repeating: 0x42, count: 32); let account = AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(), username: "Bound fixture", publicKeyData: key, settings: .init(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        let view = try XCTUnwrap(AccountCreateViewFactory.createViewForShowPassthrase(account) as? AccountCreateViewController)
        let presenter = try XCTUnwrap(view.presenter as? AccountCreatePresenter); let interactor = try XCTUnwrap(presenter.interactor as? AccountBackupInteractor)
        XCTAssertEqual(view.mode, .view); XCTAssertEqual(interactor.account.address, account.address); XCTAssertEqual(presenter.username, account.username); XCTAssertFalse(view.isViewLoaded)
    }
}
