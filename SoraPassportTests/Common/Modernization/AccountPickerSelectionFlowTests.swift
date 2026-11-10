// SPDX-License-Identifier: Apache-2.0
import Foundation
import SoraFoundation
import SoraUIKit
import RobinHood
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class AccountPickerSelectionFlowTests: XCTestCase {
  private var fixtures = [PickerFlowFixture]()
  override func tearDown() {
    fixtures.forEach { $0.repository.releaseAll() }
    fixtures = []
    super.tearDown()
  }
  private func make() async -> PickerFlowFixture {
    let f = PickerFlowFixture()
    fixtures.append(f)
    f.subject.reload()
    await wait { f.view.models.count == 3 }
    return f
  }
  private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line)
    async
  {
    for _ in 0..<200 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Account picker did not finish", file: file, line: line)
  }
  func testInitialRowsPreserveRepositoryOrderAndCurrentSelection() async {
    let f = await make()
    XCTAssertEqual(f.view.models.map(\.title), ["Wallet 0", "Wallet 1", "Wallet 2"])
    XCTAssertEqual(f.view.models.map(\.isSelected), [true, false, false])
  }
  func testUnnamedAccountUsesItsExactAddress() async {
    let f = await make()
    f.repository.rows = [PickerFlowFixture.account(3, name: "")]
    f.subject.reload()
    await wait { f.view.models.first?.title == "public-picker-3" }
    XCTAssertEqual(f.view.models.count, 1)
  }
  func testSelectionModeStartsWithNoExportSelection() async {
    let f = await make()
    f.subject.set(mode: .edit)
    XCTAssertEqual(f.view.models.map(\.isSelected), [false, false, false])
    XCTAssertTrue(f.view.models.allSatisfy(\.isMultiselectionMode))
  }
  func testExportOfOnlyLastRowUsesThatAccountRatherThanFirstRow() async {
    let f = await make()
    f.subject.set(mode: .edit)
    f.subject.selectItem(at: 2)
    f.subject.onAction()
    XCTAssertEqual(f.routes.exports.last?.map(\.address), ["public-picker-2"])
  }
  func testExportOfNonadjacentRowsPreservesTheirActualIdentities() async {
    let f = await make()
    f.subject.set(mode: .edit)
    f.subject.selectItem(at: 0)
    f.subject.selectItem(at: 2)
    f.subject.onAction()
    XCTAssertEqual(f.routes.exports.last?.map(\.address), ["public-picker-0", "public-picker-2"])
  }
  func testDeselectingARowRemovesOnlyThatAccountFromExport() async {
    let f = await make()
    f.subject.set(mode: .edit)
    f.subject.selectItem(at: 0)
    f.subject.selectItem(at: 1)
    f.subject.selectItem(at: 0)
    f.subject.onAction()
    XCTAssertEqual(f.routes.exports.last?.map(\.address), ["public-picker-1"])
  }
  func testSelectionForExportNeverChangesTheCurrentWallet() async {
    let f = await make()
    f.subject.set(mode: .edit)
    f.subject.selectItem(at: 2)
    XCTAssertTrue(f.settings.saves.isEmpty)
    XCTAssertEqual(f.settings.currentAccount?.address, "public-picker-0")
  }
  func testInvalidSelectionIndicesDoNotMutateExportChoices() async {
    let f = await make()
    f.subject.set(mode: .edit)
    f.subject.selectItem(at: -1)
    f.subject.selectItem(at: 3)
    XCTAssertTrue(f.view.models.allSatisfy { !$0.isSelected })
    XCTAssertTrue(f.settings.saves.isEmpty)
  }
  func testEmptyExportSelectionDoesNotInventAccounts() async {
    let f = await make()
    f.subject.set(mode: .edit)
    f.subject.onAction()
    XCTAssertEqual(f.routes.exports.last?.count, 0)
  }
  func testReturningToNormalModeRestoresTheDurableSelectedWallet() async {
    let f = await make()
    f.subject.set(mode: .edit)
    f.subject.selectItem(at: 2)
    f.subject.set(mode: .view)
    await wait { f.view.models.first?.isMultiselectionMode == false }
    XCTAssertEqual(f.view.models.map(\.isSelected), [true, false, false])
  }
  func testMoreActionRoutesTheExactRowAccount() async {
    let f = await make()
    f.view.models[2].onMore?()
    XCTAssertEqual(f.routes.edits.map(\.address), ["public-picker-2"])
  }
  func testInvalidEditIndicesDoNotOpenAnAccount() async {
    let f = await make()
    f.subject.editItem(at: -1)
    f.subject.editItem(at: 99)
    XCTAssertTrue(f.routes.edits.isEmpty)
  }
  func testEditingWithoutAViewDoesNotPresent() async {
    let f = await make()
    f.subject.view = nil
    f.subject.editItem(at: 1)
    XCTAssertTrue(f.routes.edits.isEmpty)
  }
  func testCurrentAccountSelectionDoesNotSaveAgain() async {
    let f = await make()
    f.subject.selectItem(at: 0)
    XCTAssertTrue(f.settings.saves.isEmpty)
    XCTAssertTrue(f.view.busy.isEmpty)
  }
  func testRowTapSavesTheExactAccount() async {
    let f = await make()
    f.view.models[1].onTap?()
    XCTAssertEqual(f.settings.saves.map(\.address), ["public-picker-1"])
    XCTAssertEqual(f.view.busy, [true])
  }
  func testOldRowTapAfterReorderingStillTargetsItsOriginalAccount() async {
    let f = await make()
    let old = f.view.models[2]
    f.repository.rows.reverse()
    f.subject.reload()
    await wait { f.view.models.first?.title == "Wallet 2" }
    old.onTap?()
    XCTAssertEqual(f.settings.saves.map(\.address), ["public-picker-2"])
  }
  func testOldMoreActionAfterReorderingStillTargetsItsOriginalAccount() async {
    let f = await make()
    let old = f.view.models[2]
    f.repository.rows.reverse()
    f.subject.reload()
    await wait { f.view.models.first?.title == "Wallet 2" }
    old.onMore?()
    XCTAssertEqual(f.routes.edits.map(\.address), ["public-picker-2"])
  }
  func testOldRowActionCannotSelectAnotherAccountAfterItsRemoval() async {
    let f = await make()
    let old = f.view.models[1]
    f.repository.rows.remove(at: 1)
    f.subject.reload()
    await wait { f.view.models.count == 2 }
    old.onTap?()
    XCTAssertTrue(f.settings.saves.isEmpty)
  }
  func testOldMoreActionCannotEditAnotherAccountAfterItsRemoval() async {
    let f = await make()
    let old = f.view.models[1]
    f.repository.rows.remove(at: 1)
    f.subject.reload()
    await wait { f.view.models.count == 2 }
    old.onMore?()
    XCTAssertTrue(f.routes.edits.isEmpty)
  }
  func testBusySwitchPreventsModeChangeAndEditing() async {
    let f = await make()
    f.subject.selectItem(at: 1)
    f.subject.set(mode: .edit)
    f.subject.editItem(at: 2)
    f.subject.onAction()
    XCTAssertTrue(f.routes.edits.isEmpty)
    XCTAssertTrue(f.routes.exports.isEmpty)
    XCTAssertEqual(f.routes.starts, 0)
    XCTAssertTrue(f.view.models.allSatisfy { !$0.isMultiselectionMode })
  }
  func testFailedSwitchRestoresDurableSelectionAndReportsTheFailure() async {
    let f = await make()
    f.subject.selectItem(at: 1)
    f.settings.finish(.failure(PickerFlowFailure.offline))
    await wait { f.view.errors == 1 }
    XCTAssertEqual(f.view.models.map(\.isSelected), [true, false, false])
    XCTAssertEqual(f.view.busy, [true, false])
  }
  func testFailedSwitchCanBeRetried() async {
    let f = await make()
    f.subject.selectItem(at: 1)
    f.settings.finish(.failure(PickerFlowFailure.offline))
    await wait { f.view.errors == 1 }
    f.subject.selectItem(at: 2)
    XCTAssertEqual(f.settings.saves.map(\.address), ["public-picker-1", "public-picker-2"])
  }
  func testSuccessfulSwitchWaitsForObserversBeforeDismissing() async {
    let f = await make()
    f.subject.selectItem(at: 1)
    f.settings.finish(.success(f.repository.rows[1]))
    await wait { f.events.completion != nil }
    XCTAssertEqual(f.view.dismissals, 0)
    XCTAssertEqual(f.view.busy, [true])
    f.events.completion?()
    XCTAssertEqual(f.view.dismissals, 1)
    XCTAssertEqual(f.view.busy, [true, false])
  }
  func testCapabilitiesStartCheckingAndUpdateTheMatchingRow() async {
    let f = await make()
    XCTAssertEqual(f.view.models[1].capabilityBadge, WalletAccountCapability.State.checking.badge)
    f.probes[1].1(.missingKeys)
    XCTAssertEqual(
      f.view.models[1].capabilityBadge, WalletAccountCapability.State.missingKeys.badge)
    XCTAssertEqual(f.view.models[0].capabilityBadge, WalletAccountCapability.State.checking.badge)
  }
  func testCapabilityFromAnOldSnapshotCannotOverwriteAReorderedRow() async {
    let f = await make()
    let old = f.probes[0].1
    f.repository.rows.reverse()
    f.subject.reload()
    await wait { f.view.models.first?.title == "Wallet 2" }
    old(.missingKeys)
    XCTAssertEqual(f.view.models[0].capabilityBadge, WalletAccountCapability.State.checking.badge)
  }
  func testAnOlderAccountReadCannotReplaceANewerReload() async {
    let f = await make()
    let hold = f.repository.holdNext()
    f.subject.reload()
    await wait { hold.started }
    f.repository.rows = [PickerFlowFixture.account(4)]
    f.subject.reload()
    await wait { f.view.models.first?.title == "Wallet 4" }
    hold.release()
    await wait { hold.finished }
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(f.view.models.map(\.title), ["Wallet 4"])
  }
  func testAddAccountRouteUsesCurrentInventoryForRetainedWalletDiscovery() async {
    let f = await make()
    f.subject.onAction()
    await wait { f.routes.starts == 1 }
    XCTAssertEqual(f.discovery.addresses, Set(f.repository.rows.map(\.address)))
  }
  func testFinishingAccountCreationReloadsRowsAndChecksMigration() async {
    let f = await make()
    f.subject.onAction()
    await wait { f.routes.startCompletion != nil }
    f.repository.rows.append(PickerFlowFixture.account(3))
    f.routes.startCompletion?()
    await wait { f.view.models.count == 4 }
    XCTAssertEqual(f.services.checks, 1)
  }
  func testEndUpdatingForwardsItsCompletionOncePerCall() async {
    let f = await make()
    var n = 0
    f.subject.endUpdatingBlock = { n += 1 }
    f.subject.endUpdating()
    XCTAssertEqual(n, 1)
  }
  func testPresenterIsNotRetainedByRowsOrCapabilityCallbacks() async {
    var f: PickerFlowFixture? = await make()
    weak var p = f?.subject
    let rows = f!.view.models
    let callbacks = f!.probes
    f!.subject = nil
    f = nil
    XCTAssertNil(p)
    rows.forEach {
      $0.onMore?()
      $0.onTap?()
    }
    callbacks.forEach { $0.1(.missingKeys) }
  }
}
private enum PickerFlowFailure: Error { case offline }
@MainActor private final class PickerFlowFixture {
  static func account(_ i: Int, name: String? = nil) -> AccountItem {
    .init(
      address: "public-picker-\(i)", cryptoType: .sr25519, networkType: Chain.sora.addressType(),
      username: name ?? "Wallet \(i)", publicKeyData: Data(repeating: UInt8(i), count: 32),
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: Int16(i),
      isSelected: i == 0)
  }
  var subject: ChangeAccountPresenter!
  let repository = PickerFlowRepository(), settings = PickerFlowSettings(), view = PickerFlowView(),
    routes = PickerFlowRoutes(), events = PickerFlowEvents(), services = PickerFlowServices(),
    discovery = PickerFlowDiscovery()
  var probes = [(String, (WalletAccountCapability.State) -> Void)]()
  init() {
    repository.rows = (0..<3).map { Self.account($0) }
    settings.currentAccount = repository.rows.first
    subject = ChangeAccountPresenter(
      settingsManager: settings, eventCenter: events,
      accountRepository: AnyDataProviderRepository(repository),
      operationManager: OperationManager(), serviceCoordinator: services,
      capabilityProbe: { [weak self] a, c in self?.probes.append((a.address, c)) },
      retainedWallets: { [discovery] addresses in
        discovery.set(addresses)
        return []
      })
    subject.view = view
    subject.wireframe = routes
  }
}
private final class PickerFlowDiscovery: @unchecked Sendable {
  private let lock = NSLock()
  private var value = Set<String>()
  func set(_ x: Set<String>) {
    lock.lock()
    value = x
    lock.unlock()
  }
  var addresses: Set<String> {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}
private final class PickerFlowView: UIViewController, ChangeAccountViewProtocol {
  var controller: UIViewController { self }
  var presenter: ChangeAccountPresenterProtocol?
  var models = [AccountMenuItem](), busy = [Bool](), errors = 0, dismissals = 0
  var usesSystemDismissal = false
  func update(with accountViewModels: [AccountMenuItem]) { models = accountViewModels }
  func setSwitchingAccount(_ switching: Bool) { busy.append(switching) }
  func showAccountSwitchError() { errors += 1 }
  override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
    dismissals += 1
    if usesSystemDismissal { super.dismiss(animated: animated, completion: completion) }
    else { completion?() }
  }
}
private final class PickerFlowRoutes: ChangeAccountWireframeProtocol {
  var edits = [AccountItem](), exports = [[AccountItem]](), starts = 0
  var startCompletion: (() -> Void)?
  func showStart(from view: UIViewController, completion: @escaping () -> Void) {
    starts += 1
    startCompletion = completion
  }
  func showEdit(account: AccountItem, from controller: UIViewController) { edits.append(account) }
  func showExportAccounts(accounts: [AccountItem], from controller: UIViewController) {
    exports.append(accounts)
  }
  func showSignUp(from view: UIViewController, completion: @escaping () -> Void) {
    XCTFail("unexpected sign up")
  }
  func showAccountRestore(from view: UIViewController, completion: @escaping () -> Void) {
    XCTFail("unexpected restore")
  }
}
private final class PickerFlowEvents: EventCenterProtocol {
  var completion: (() -> Void)?
  func notify(with event: EventProtocol) {}
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    completion = completionOnMain
  }
  func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
  func remove(observer: EventVisitorProtocol) {}
}
private final class PickerFlowServices: ServiceCoordinatorProtocol {
  var checks = 0
  func setup() {}
  func throttle() {}
  func updateOnAccountChange() {}
  func updateOnNetworkChange() {}
  func checkMigration() { checks += 1 }
}
private final class PickerFlowSettings: SelectedWalletSettingsProtocol {
  var currentAccount: AccountItem?, saves = [AccountItem]()
  var pending: ((Result<AccountItem, Error>) -> Void)?
  func performSave(
    value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) {
    saves.append(value)
    pending = completionClosure
  }
  func finish(_ r: Result<AccountItem, Error>) {
    if case .success(let a) = r { currentAccount = a }
    let c = pending
    pending = nil
    c?(r)
  }
  func performInsertAndSelect(
    prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void,
    lifecycleLease: WalletLifecycleLease,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail() }
  func performSelectAfterRemoval(
    value: AccountItem, lifecycleLease: WalletLifecycleLease,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail() }
  func performUpdateName(
    account: AccountItem, displayName: String,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail() }
  func performUpdateAssetSettings(
    account: AccountItem, settings: AccountSettings,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail() }
  func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) {
    completionClosure(.success(currentAccount))
  }
  func save(value: AccountItem) { XCTFail() }
}
private final class PickerFlowHold: @unchecked Sendable {
  private let condition = NSCondition()
  private var open = false, began = false, done = false
  var started: Bool {
    condition.lock()
    defer { condition.unlock() }
    return began
  }
  var finished: Bool {
    condition.lock()
    defer { condition.unlock() }
    return done
  }
  func wait() {
    condition.lock()
    began = true
    while !open { condition.wait() }
    done = true
    condition.unlock()
  }
  func release() {
    condition.lock()
    open = true
    condition.broadcast()
    condition.unlock()
  }
}
private final class PickerFlowRepository: DataProviderRepositoryProtocol {
  typealias Model = AccountItem
  var rows = [AccountItem]()
  private var next: PickerFlowHold?
  private var holds = [PickerFlowHold]()
  func holdNext() -> PickerFlowHold {
    let h = PickerFlowHold()
    next = h
    holds.append(h)
    return h
  }
  func releaseAll() { holds.forEach { $0.release() } }
  func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[AccountItem]> {
    let rows = rows
    let hold = next
    next = nil
    return ClosureOperation {
      hold?.wait()
      return rows
    }
  }
  func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions)
    -> BaseOperation<[AccountItem]>
  { ClosureOperation { [] } }
  func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions)
    -> BaseOperation<AccountItem?>
  { ClosureOperation { nil } }
  func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions)
    -> BaseOperation<[AccountItem]>
  { fetchAllOperation(with: options) }
  func saveOperation(
    _ updates: @escaping () throws -> [AccountItem], _ deletes: @escaping () throws -> [String]
  ) -> BaseOperation<Void> { ClosureOperation { XCTFail("unexpected mutation") } }
  func saveBatchOperation(
    _ updates: @escaping () throws -> [AccountItem], _ deletes: @escaping () throws -> [String]
  ) -> BaseOperation<Void> { saveOperation(updates, deletes) }
  func replaceOperation(_ models: @escaping () throws -> [AccountItem]) -> BaseOperation<Void> {
    ClosureOperation { XCTFail("unexpected mutation") }
  }
  func deleteAllOperation() -> BaseOperation<Void> {
    ClosureOperation { XCTFail("unexpected mutation") }
  }
  func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.rows.count } }
}

@MainActor
final class AccountPickerScreenCoverageTests: RootActionFixtureTests {
    private func open() -> (ChangeAccountViewController, PickerScreenPresenter, UINavigationController) {
        let presenter = PickerScreenPresenter(), view = ChangeAccountViewController()
        view.presenter = presenter; view.localizationManager = LocalizationManager(localization: "en")
        let navigation = UINavigationController(rootViewController: view)
        mount(navigation); view.loadViewIfNeeded(); window.layoutIfNeeded()
        return (view, presenter, navigation)
    }
    private func invoke(_ item: UIBarButtonItem?) throws {
        let item = try XCTUnwrap(item), action = try XCTUnwrap(item.action)
        _ = (item.target as? NSObject)?.perform(action)
    }
    func testLoadingAndAppearanceRequestFreshAccountRows() {
        let (view, presenter, _) = open(); let count = presenter.reloads
        XCTAssertGreaterThan(count, 0); view.viewWillAppear(false)
        XCTAssertEqual(presenter.reloads, count + 1)
    }
    func testDisappearanceEndsAccountUpdates() {
        let (view, presenter, _) = open(); view.viewWillDisappear(false); XCTAssertEqual(presenter.ends, 1)
    }
    func testEditModeUpdatesBarActionAndPresenter() throws {
        let (view, presenter, _) = open(); _ = view.perform(NSSelectorFromString("onEdit"))
        XCTAssertEqual(view.navigationItem.leftBarButtonItem?.title, R.string.localizable.commonDone(preferredLanguages: ["en"]))
        XCTAssertEqual(presenter.modes.last, "edit")
        XCTAssertTrue(all(SoramitsuButton.self, view.view).contains { $0.sora.title == R.string.localizable.backupAccountTitle(preferredLanguages: ["en"]) })
    }
    func testDoneButtonReturnsToAccountSelection() throws {
        let (view, presenter, _) = open(); _ = view.perform(NSSelectorFromString("onEdit"))
        try invoke(view.navigationItem.leftBarButtonItem)
        XCTAssertEqual(presenter.modes, ["edit", "view"])
        XCTAssertEqual(view.navigationItem.leftBarButtonItem?.title, R.string.localizable.commonEdit(preferredLanguages: ["en"]))
        XCTAssertTrue(all(SoramitsuButton.self, view.view).contains { $0.sora.title == R.string.localizable.accountAdd(preferredLanguages: ["en"]) })
    }
    func testActionButtonForwardsExactlyOnePresenterAction() throws {
        let (view, presenter, _) = open(); _ = view.perform(NSSelectorFromString("onAction")); XCTAssertEqual(presenter.actions, 1)
    }
    func testSwitchProgressDisablesRowsAndProtectsTheModal() throws {
        let (view, _, navigation) = open(); _ = view.perform(NSSelectorFromString("onEdit"))
        view.setSwitchingAccount(true)
        XCTAssertTrue(view.isModalInPresentation); XCTAssertTrue(navigation.isModalInPresentation)
        XCTAssertFalse(try XCTUnwrap(all(UITableView.self, view.view).first).isUserInteractionEnabled)
        XCTAssertFalse(try XCTUnwrap(view.navigationItem.leftBarButtonItem).isEnabled)
        XCTAssertFalse(try XCTUnwrap(all(UIView.self, view.view).first { $0.accessibilityIdentifier == "wallet-account-switch-progress" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(all(UIActivityIndicatorView.self, view.view).first { $0.accessibilityIdentifier == "wallet-account-switch-spinner" }).isAnimating)
    }
    func testSwitchCompletionRestoresInteractionAndStopsProgress() throws {
        let (view, _, navigation) = open(); _ = view.perform(NSSelectorFromString("onEdit"))
        view.setSwitchingAccount(true); view.setSwitchingAccount(false)
        XCTAssertFalse(view.isModalInPresentation); XCTAssertFalse(navigation.isModalInPresentation)
        XCTAssertTrue(try XCTUnwrap(all(UITableView.self, view.view).first).isUserInteractionEnabled)
        XCTAssertTrue(try XCTUnwrap(view.navigationItem.leftBarButtonItem).isEnabled)
        XCTAssertTrue(try XCTUnwrap(all(UIView.self, view.view).first { $0.accessibilityIdentifier == "wallet-account-switch-progress" }).isHidden)
        XCTAssertFalse(try XCTUnwrap(all(UIActivityIndicatorView.self, view.view).first { $0.accessibilityIdentifier == "wallet-account-switch-spinner" }).isAnimating)
    }
    func testSwitchFailureExplainsThatTheOriginalAccountRemainsSelected() async throws {
        let (view, _, _) = open(); view.showAccountSwitchError(); await settle()
        XCTAssertEqual(try alert(view).title, "Couldn’t switch accounts")
        XCTAssertEqual(try alert(view).message, "Your current account is still selected. Please try again.")
        XCTAssertEqual(try alert(view).actions.map(\.title), ["OK"])
    }
    func testEmptySnapshotRemovesEveryAccountRow() throws {
        let (view, _, _) = open(); view.update(with: [])
        let table = try XCTUnwrap(all(UITableView.self, view.view).first)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)
    }
    func testAccountRowsKeepTheirExactTitlesAndSelection() throws {
        let (view, _, _) = open()
        let models = (0..<3).map { AccountMenuItem(title: "Wallet \($0)", image: nil, isSelected: $0 == 1, isMultiselectionMode: false, onTap: {}, onMore: {}) }
        view.update(with: models)
        let table = try XCTUnwrap(all(UITableView.self, view.view).first)
        window.layoutIfNeeded(); view.view.layoutIfNeeded(); table.layoutIfNeeded()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 3)
        XCTAssertTrue(texts(view).contains("Wallet 0")); XCTAssertTrue(texts(view).contains("Wallet 1"))
    }
    func testLargeAccountSnapshotKeepsTheActionBelowAViewportBoundTable() throws {
        let (view, _, _) = open()
        view.update(with: (0..<40).map { AccountMenuItem(title: "Wallet \($0)", image: nil, isSelected: false, isMultiselectionMode: false, onTap: {}, onMore: {}) })
        let table = try XCTUnwrap(all(UITableView.self, view.view).first)
        window.layoutIfNeeded(); view.view.layoutIfNeeded(); table.layoutIfNeeded()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 40)
        XCTAssertGreaterThan(table.bounds.height, 0)
        XCTAssertLessThanOrEqual(table.bounds.height, view.view.bounds.height)
        XCTAssertGreaterThan(table.contentSize.height, table.bounds.height)
    }
    func testLanguageChangeUpdatesTheAccountTitleAndAction() {
        let (view, _, _) = open(); view.localizationManager?.selectedLocalization = "ja"; view.applyLocalization()
        XCTAssertEqual(view.navigationItem.title, R.string.localizable.commonAccount(preferredLanguages: ["ja"]))
    }
    func testModeMetadataKeepsTheAddIconOutOfBackupMode() {
        XCTAssertNotNil(ChangeAccountViewController.Mode.view.actionIcon)
        XCTAssertNil(ChangeAccountViewController.Mode.edit.actionIcon)
        XCTAssertEqual(ChangeAccountViewController.Mode.view.actionTitle, R.string.localizable.accountAdd(preferredLanguages: ["en"]))
        XCTAssertEqual(ChangeAccountViewController.Mode.edit.actionTitle, R.string.localizable.backupAccountTitle(preferredLanguages: ["en"]))
    }
}

private final class PickerScreenPresenter: ChangeAccountPresenterProtocol {
    weak var view: ChangeAccountViewProtocol?
    var reloads = 0, ends = 0, actions = 0
    var modes = [String](), selections = [Int](), edits = [Int]()
    func onAction() { actions += 1 }
    func set(mode: ChangeAccountViewController.Mode) { modes.append(mode == .edit ? "edit" : "view") }
    func reload() { reloads += 1 }
    func selectItem(at index: Int) { selections.append(index) }
    func editItem(at index: Int) { edits.append(index) }
    func endUpdating() { ends += 1 }
}

@MainActor
final class AccountPickerRetainedRouteCoverageTests: RootActionFixtureTests {
    private var fixtures = [PickerFlowFixture]()
    override func tearDown() async throws {
        fixtures.forEach { $0.repository.releaseAll() }; fixtures = []
        try await super.tearDown()
    }
    private func open(restore: @escaping ChangeAccountPresenter.RetainedRestore = { _, _, _, _ in XCTFail("Restoration requires an explicit choice") }) async -> PickerFlowFixture {
        let f = PickerFlowFixture(); fixtures.append(f); f.view.usesSystemDismissal = true
        let retained = RetainedKeychainWallet(address: "retained-public-fixture", publicKey: Data(repeating: 8, count: 32), cryptoType: .sr25519, networkType: Chain.sora.addressType(), derivationPath: nil, hasPhrase: true)
        f.subject = ChangeAccountPresenter(settingsManager: f.settings, eventCenter: f.events,
            accountRepository: AnyDataProviderRepository(f.repository), operationManager: OperationManager(), serviceCoordinator: f.services,
            capabilityProbe: { _, completed in completed(.checking) }, retainedWallets: { _ in [retained] }, retainedRestore: restore)
        f.subject.view = f.view; f.subject.wireframe = f.routes; mount(f.view)
        f.subject.reload(); await wait { f.view.models.count == 3 }; return f
    }
    private func start(_ f: PickerFlowFixture) async throws {
        f.subject.onAction(); await wait { f.view.presentedViewController != nil }
        try await choose("Restore wallets found on this iPhone", f.view)
    }
    func testRetainedWalletsOfferAnExplicitChoiceInsteadOfImmediatelyRestoring() async throws {
        let f = await open(); f.subject.onAction(); await wait { f.view.presentedViewController != nil }
        XCTAssertEqual(try alert(f.view).actions.map(\.title), ["Restore wallets found on this iPhone", "Create or import an account", "Cancel"])
        XCTAssertEqual(f.routes.starts, 0)
    }
    func testRetainedChoiceCanBeCancelledWithoutChangingSelection() async throws {
        let f = await open(); f.subject.onAction(); await wait { f.view.presentedViewController != nil }
        try await choose("Cancel", f.view); XCTAssertEqual(f.routes.starts, 0); XCTAssertTrue(f.settings.saves.isEmpty)
    }
    func testCreateOrImportChoiceKeepsTheExistingAddAccountRoute() async throws {
        let f = await open(); f.subject.onAction(); await wait { f.view.presentedViewController != nil }
        try await choose("Create or import an account", f.view); XCTAssertEqual(f.routes.starts, 1)
    }
    func testRetainedRestoreUsesAfterSetupAuthorityAndDisablesInteractionWhileBusy() async throws {
        var captured: ((Bool) -> Void)?, capturedController: UIViewController?, capturedScope: WalletRetainedPinGate.Scope?
        let f = await open { controller, scope, busy, _ in captured = busy; capturedController = controller; capturedScope = scope; busy(true) }
        try await start(f); XCTAssertTrue(capturedController === f.view); XCTAssertEqual(capturedScope, .afterSetup)
        XCTAssertFalse(f.view.view.isUserInteractionEnabled); captured?(false); XCTAssertTrue(f.view.view.isUserInteractionEnabled)
    }
    func testCompleteRetainedRestoreRefreshesTheExactRepositorySnapshot() async throws {
        var finish: ((WalletRetainedWalletRestoreFlow.Outcome) -> Void)?
        let f = await open { _, _, _, completion in finish = completion }; try await start(f)
        f.repository.rows.append(PickerFlowFixture.account(8)); finish?(.restored(count: 1, failed: 0))
        await wait { f.view.models.count == 4 }; XCTAssertEqual(f.view.models.last?.title, "Wallet 8")
        XCTAssertNil(f.view.presentedViewController)
    }
    func testPartialRestoreKeepsNewRowsButWaitsForAcknowledgementBeforeReload() async throws {
        var finish: ((WalletRetainedWalletRestoreFlow.Outcome) -> Void)?
        let f = await open { _, _, _, completion in finish = completion }; try await start(f)
        f.repository.rows.append(PickerFlowFixture.account(8)); finish?(.restored(count: 1, failed: 2))
        XCTAssertEqual(f.view.models.count, 3); XCTAssertEqual(try alert(f.view).title, "Some wallets were restored")
        XCTAssertTrue(try alert(f.view).message?.contains("Restored: 1. Not restored: 2.") == true)
        try await choose("OK", f.view); await wait { f.view.models.count == 4 }
    }
    func testFailedRetainedRestoreShowsItsReasonAndKeepsTheSelectedAccount() async throws {
        let f = await open { _, _, _, complete in complete(.nothingRestored(message: "Ownership PIN was rejected")) }
        try await start(f); XCTAssertEqual(try alert(f.view).title, "Wallet restore")
        XCTAssertEqual(try alert(f.view).message, "Ownership PIN was rejected")
        XCTAssertEqual(f.settings.currentAccount?.address, "public-picker-0"); XCTAssertEqual(f.view.models.count, 3)
    }
    func testCommittedRowsNeedingPinSetupShowTheExactRecoveryMessage() async throws {
        let f = await open { _, _, _, complete in complete(.setupRequired(count: 1, message: "Saved wallet needs PIN setup")) }
        try await start(f); XCTAssertEqual(try alert(f.view).message, "Saved wallet needs PIN setup")
        XCTAssertTrue(f.settings.saves.isEmpty)
    }
    func testAddActionWithoutAViewDoesNotStartRetainedDiscoveryOrNavigation() async {
        let f = await open(); f.subject.view = nil; f.subject.onAction(); await settle(); XCTAssertEqual(f.routes.starts, 0)
    }
    func testExportActionWithoutAViewDoesNotPresent() async {
        let f = await open(); f.subject.set(mode: .edit); f.subject.selectItem(at: 1); f.subject.view = nil
        f.subject.onAction(); XCTAssertTrue(f.routes.exports.isEmpty)
    }
}

@MainActor
final class PortfolioAccountSwitcherCoverageTests: XCTestCase {
    private func wait(_ predicate: () -> Bool) async {
        for _ in 0..<200 { if predicate() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(predicate())
    }
    private func make() -> (PortfolioAccountSwitcher, PickerFlowFixture, OperationQueue) {
        let fixture = PickerFlowFixture(), queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        return (PortfolioAccountSwitcher(repository: AnyDataProviderRepository(fixture.repository), settings: fixture.settings, eventCenter: fixture.events, operationQueue: queue), fixture, queue)
    }
    func testSelectedWalletIdTracksTheScopedDurableSelection() {
        let (switcher, f, _) = make(); XCTAssertEqual(switcher.selectedWalletId, "public-picker-0")
        f.settings.currentAccount = f.repository.rows[2]; XCTAssertEqual(switcher.selectedWalletId, "public-picker-2")
        f.settings.currentAccount = nil; XCTAssertNil(switcher.selectedWalletId)
    }
    func testUnknownWalletReturnsFalseWithoutSavingOrPublishingAnEvent() async {
        let (switcher, f, _) = make(); var results = [Bool]()
        switcher.switchTo(walletId: "unknown") { results.append($0) }; await wait { !results.isEmpty }
        XCTAssertEqual(results, [false]); XCTAssertTrue(f.settings.saves.isEmpty); XCTAssertNil(f.events.completion)
    }
    func testRequestedWalletUsesItsRepositoryIdentityAndWaitsForDurableSave() async {
        let (switcher, f, _) = make(); var results = [Bool]()
        switcher.switchTo(walletId: "public-picker-2") { results.append($0) }; await wait { !f.settings.saves.isEmpty }
        XCTAssertEqual(f.settings.saves.map(\.address), ["public-picker-2"])
        XCTAssertTrue(results.isEmpty); XCTAssertNil(f.events.completion)
    }
    func testSuccessfulSelectionWaitsForAllEventObserversBeforeReportingSuccess() async {
        let (switcher, f, _) = make(); var results = [Bool]()
        switcher.switchTo(walletId: "public-picker-1") { results.append($0) }; await wait { f.settings.pending != nil }
        f.settings.finish(.success(f.repository.rows[1])); await wait { f.events.completion != nil }
        XCTAssertTrue(results.isEmpty); XCTAssertEqual(switcher.selectedWalletId, "public-picker-1")
        f.events.completion?(); XCTAssertEqual(results, [true])
    }
    func testFailedSelectionReportsFalseWithoutPublishingTheChangeEvent() async {
        let (switcher, f, _) = make(); var results = [Bool]()
        switcher.switchTo(walletId: "public-picker-1") { results.append($0) }; await wait { f.settings.pending != nil }
        f.settings.finish(.failure(PickerFlowFailure.offline)); await wait { !results.isEmpty }
        XCTAssertEqual(results, [false]); XCTAssertNil(f.events.completion); XCTAssertEqual(switcher.selectedWalletId, "public-picker-0")
    }
    func testEmptyRepositoryCannotInventASelection() async {
        let (switcher, f, _) = make(); f.repository.rows = []; var results = [Bool]()
        switcher.switchTo(walletId: "public-picker-0") { results.append($0) }; await wait { !results.isEmpty }
        XCTAssertEqual(results, [false]); XCTAssertTrue(f.settings.saves.isEmpty)
    }
    func testSuspendedQueueDoesNotStartAccountSavingBeforeRepositoryRead() async {
        let (switcher, f, queue) = make(); queue.isSuspended = true
        switcher.switchTo(walletId: "public-picker-1") { _ in }
        try? await Task.sleep(nanoseconds: 30_000_000); XCTAssertTrue(f.settings.saves.isEmpty)
        queue.isSuspended = false; await wait { f.settings.pending != nil }
        f.settings.finish(.failure(PickerFlowFailure.offline))
    }
    func testCompletionIsDeliveredOnMainThread() async {
        let (switcher, _, _) = make(); var completed = false
        switcher.switchTo(walletId: "unknown") { _ in XCTAssertTrue(Thread.isMainThread); completed = true }
        await wait { completed }
    }
}
