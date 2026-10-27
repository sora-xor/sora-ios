import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SoraUIKit
@testable import SoraPassport

final class ChangeAccountTests: XCTestCase {
    @MainActor
    func testExportRequiresSixCharactersEvenWhenTheActionIsCalledDirectly() throws {
        let presenter = ExportPasswordPresenterSpy()
        let view = AccountExportViewController()
        view.presenter = presenter
        view.localizationManager = LocalizationManager.shared
        view.loadViewIfNeeded()
        let fields = descendants(view.view).compactMap { $0 as? InputField }
        XCTAssertEqual(fields.count, 2)
        let password = try XCTUnwrap(fields.first)
        let confirmation = try XCTUnwrap(fields.last)
        let button = try XCTUnwrap(descendants(view.view).compactMap { $0 as? SoramitsuButton }.first)

        func edit(_ value: String) {
            password.sora.text = value
            password.textField.sendActions(for: .editingChanged)
            confirmation.sora.text = value
            confirmation.textField.sendActions(for: .editingChanged)
        }

        edit("12345")
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(password.sora.state, .fail)
        XCTAssertFalse((password.sora.descriptionLabelText ?? "").isEmpty)
        view.downloadTapped()
        XCTAssertTrue(presenter.passwords.isEmpty)

        edit("123456")
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(password.sora.state, .success)
        view.downloadTapped()
        XCTAssertEqual(presenter.passwords, ["123456"])
    }

    func testUnsupportedNetworkImportExplainsHowToProceed() {
        let content = AccountCreateError.unsupportedNetwork.toErrorContent(for: Locale(identifier: "en"))
        XCTAssertFalse(content.title.isEmpty)
        XCTAssertTrue(content.message.contains("network"))
        XCTAssertTrue(content.message.contains("SORA wallet backup"))
    }

    func testJSONImportErrorsExplainTheFileOrPasswordProblem() {
        for language in ["en", "ja"] {
            let locale = Locale(identifier: language)
            let malformed = AccountOperationFactoryError.invalidKeystore.toErrorContent(for: locale)
            let password = AccountOperationFactoryError.decryption.toErrorContent(for: locale)
            XCTAssertNotEqual(malformed.title, password.title)
            XCTAssertFalse(malformed.message.isEmpty)
            XCTAssertFalse(password.message.isEmpty)
            XCTAssertTrue(malformed.message.contains("JSON"))
            XCTAssertTrue(password.message.contains("PIN"))
            XCTAssertFalse(password.message.contains("Undefined error"))
        }
    }

    @MainActor
    func testSwitchStaysBusyUntilSelectionObserversFinishAndIgnoresRepeatedTaps() throws {
        let (presenter, view, settings, events) = try picker()
        presenter.selectItem(at: 1)
        XCTAssertEqual(view.busyStates, [true])
        presenter.selectItem(at: 0)
        presenter.selectItem(at: 1)
        XCTAssertEqual(settings.saveCalls, 1)
        let notified = expectation(description: "durable selection delivered")
        events.onNotify = { notified.fulfill() }
        settings.finish(.success(settings.accounts[1]))
        wait(for: [notified], timeout: 2)
        XCTAssertEqual(view.busyStates, [true], "the picker stays covered while account providers rebind")
        XCTAssertFalse(view.dismissed)
        events.completion?()
        XCTAssertTrue(view.dismissed)
        XCTAssertEqual(view.busyStates, [true, false])
    }

    @MainActor
    func testFailedSelectionRestoresCurrentAccountAndAllowsRetry() throws {
        let (presenter, view, settings, _) = try picker()
        presenter.selectItem(at: 1)
        let failed = expectation(description: "failure displayed")
        view.onFailure = { failed.fulfill() }
        settings.finish(.failure(NSError(domain: "synthetic-save-failure", code: 1)))
        wait(for: [failed], timeout: 2)
        XCTAssertEqual(view.busyStates, [true, false])
        XCTAssertTrue(view.models[0].isSelected)
        XCTAssertFalse(view.models[1].isSelected)
        XCTAssertFalse(view.dismissed)
        presenter.selectItem(at: 1)
        XCTAssertEqual(settings.saveCalls, 2)
    }

    @MainActor
    func testProgressIsVisibleAccessibleAndBlocksDismissalInBothThemes() throws {
        let previousTheme = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previousTheme }
        for theme in [SoramitsuThemeMode.manual(.dark), .manual(.light)] {
            SoramitsuUI.shared.themeMode = theme
            let controller = ChangeAccountViewController()
            let navigation = UINavigationController(rootViewController: controller)
            controller.loadViewIfNeeded()
            controller.setSwitchingAccount(true)
            let views = descendants(controller.view)
            let cover = try XCTUnwrap(views.first { $0.accessibilityIdentifier == "wallet-account-switch-progress" })
            let spinner = try XCTUnwrap(views.first { $0.accessibilityIdentifier == "wallet-account-switch-spinner" } as? UIActivityIndicatorView)
            XCTAssertFalse(cover.isHidden)
            XCTAssertTrue(cover.accessibilityViewIsModal)
            XCTAssertTrue(spinner.isAnimating)
            XCTAssertTrue(navigation.isModalInPresentation)
            XCTAssertTrue(controller.navigationItem.rightBarButtonItems?.allSatisfy { !$0.isEnabled } ?? true)
            controller.setSwitchingAccount(false)
            XCTAssertTrue(cover.isHidden)
            XCTAssertFalse(spinner.isAnimating)
            XCTAssertFalse(navigation.isModalInPresentation)
        }
    }

    @MainActor
    func testLanguageRowOpensTheInAppLanguagePicker() throws {
        let presenter = AppSettingsPresenter()
        let view = SettingsViewSpy()
        let navigation = UINavigationController(rootViewController: view)
        presenter.view = view
        presenter.localizationManager = LocalizationManager.shared
        presenter.reload()
        let item = try XCTUnwrap(view.model?.sections.first?.rows.first as? AppSettingsItem)
        item.onTap?()
        XCTAssertTrue(navigation.topViewController is LanguageView)
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    @MainActor
    private func picker() throws -> (ChangeAccountPresenter, SwitchViewSpy, SwitchSettings, SwitchEvents) {
        let accounts = (0...1).map { index in
            AccountItem(address: "public-switch-fixture-\(index)", cryptoType: .sr25519, networkType: ApplicationConfig.shared.addressType,
                        username: "Fixture \(index)", publicKeyData: Data(repeating: UInt8(index), count: 32),
                        settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: Int16(index), isSelected: index == 0)
        }
        let settings = SwitchSettings(accounts: accounts)
        let events = SwitchEvents()
        let view = SwitchViewSpy()
        let presenter = ChangeAccountPresenter(settingsManager: settings, eventCenter: events,
            accountRepository: AnyDataProviderRepository(SwitchRepository(accounts: accounts)),
            operationManager: OperationManagerFacade.sharedManager, serviceCoordinator: SwitchServices())
        presenter.view = view
        let loaded = expectation(description: "accounts loaded")
        view.onUpdate = { view.onUpdate = nil; loaded.fulfill() }
        presenter.reload()
        wait(for: [loaded], timeout: 2)
        return (presenter, view, settings, events)
    }
}

private final class SwitchViewSpy: UIViewController, ChangeAccountViewProtocol {
    var controller: UIViewController { self }
    var presenter: ChangeAccountPresenterProtocol?
    var models: [AccountMenuItem] = []
    var busyStates: [Bool] = []
    var dismissed = false
    var onUpdate: (() -> Void)?
    var onFailure: (() -> Void)?
    func update(with accountViewModels: [AccountMenuItem]) { models = accountViewModels; onUpdate?() }
    func setSwitchingAccount(_ switching: Bool) { busyStates.append(switching) }
    func showAccountSwitchError() { onFailure?() }
    override func dismiss(animated: Bool, completion: (() -> Void)? = nil) { dismissed = true; completion?() }
}

private final class SettingsViewSpy: UIViewController, AppSettingsViewProtocol {
    var controller: UIViewController { self }
    var presenter: AppSettingsPresenterProtocol?
    var model: AppSettingsModel?
    func update(model: AppSettingsModel) { self.model = model }
}

private final class SwitchEvents: EventCenterProtocol {
    var onNotify: (() -> Void)?
    var completion: (() -> Void)?
    func notify(with event: EventProtocol) {}
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
        completion = completionOnMain; onNotify?()
    }
    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}

private final class SwitchSettings: SelectedWalletSettingsProtocol {
    let accounts: [AccountItem]
    var currentAccount: AccountItem?
    var saveCalls = 0
    private var pending: ((Result<AccountItem, Error>) -> Void)?
    init(accounts: [AccountItem]) { self.accounts = accounts; currentAccount = accounts.first }
    func performSave(value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) {
        saveCalls += 1; pending = completionClosure
    }
    func finish(_ result: Result<AccountItem, Error>) {
        if case .success(let account) = result { currentAccount = account }
        let callback = pending; pending = nil; callback?(result)
    }
    func performInsertAndSelect(prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void,
        lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("unexpected insert") }
    func performSelectAfterRemoval(value: AccountItem, lifecycleLease: WalletLifecycleLease,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("unexpected removal") }
    func performUpdateName(account: AccountItem, displayName: String,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("unexpected rename") }
    func performUpdateAssetSettings(account: AccountItem, settings: AccountSettings,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("unexpected asset mutation") }
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) { completionClosure(.success(currentAccount)) }
    func save(value: AccountItem) { XCTFail("unexpected synchronous save") }
}

private final class SwitchServices: ServiceCoordinatorProtocol {
    func setup() {}
    func throttle() {}
    func updateOnAccountChange() {}
    func updateOnNetworkChange() {}
    func checkMigration() {}
}

private struct SwitchRepository: DataProviderRepositoryProtocol {
    typealias Model = AccountItem
    let accounts: [AccountItem]
    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[AccountItem]> { ClosureOperation { accounts } }
    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[AccountItem]> { ClosureOperation { [] } }
    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<AccountItem?> { ClosureOperation { nil } }
    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[AccountItem]> { fetchAllOperation(with: options) }
    func saveOperation(_ updates: @escaping () throws -> [AccountItem], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> { fatalError("read-only fixture") }
    func saveBatchOperation(_ updates: @escaping () throws -> [AccountItem], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> { fatalError("read-only fixture") }
    func replaceOperation(_ models: @escaping () throws -> [AccountItem]) -> BaseOperation<Void> { fatalError("read-only fixture") }
    func deleteAllOperation() -> BaseOperation<Void> { fatalError("read-only fixture") }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { accounts.count } }
}

private final class ExportPasswordPresenterSpy: AccountExportPresenterProtocol {
    var passwords: [String] = []

    func exportWith(password: String) {
        passwords.append(password)
    }
}
