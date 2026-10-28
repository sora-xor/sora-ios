// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import RobinHood
import IrohaCrypto
import SSFUtils
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ContactSearchLifecycleTests: XCTestCase {
    private var previous: AccountItem?
    override func setUp() { super.setUp(); previous = SelectedWalletSettings.shared.currentAccount; SelectedWalletSettings.shared.commitInternalValue(nil) }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown() }
    private func pause(_ milliseconds: UInt64 = 40) async { try? await Task.sleep(nanoseconds: milliseconds * 1_000_000) }
    private func fixture(contacts: [SearchData] = [], local: ContactsLocalSearchEngineProtocol? = nil) -> (ContactsViewModel, ContactSearchService, ContactSearchView, ContactSearchRoutes) {
        let network = ContactSearchService(); let factory = WalletNetworkOperationFactoryProtocolMock(); let route = ContactSearchRoutes(); let view = ContactSearchView()
        let provider = SingleValueProvider<[SearchData]>(targetIdentifier: "contacts-fixture", source: AnySingleValueProviderSource { CompoundOperationWrapper(targetOperation: ClosureOperation<[SearchData]?> { contacts }) }, repository: AnyDataProviderRepository(ContactSearchCache()), updateTrigger: DataProviderEventTrigger.onInitialization)
        let model = ContactsViewModel(dataProvider: provider, walletService: network, assetId: WalletAssetId.xor.rawValue, localSearchEngine: local,
            wireframe: route, networkFacade: factory, assetManager: ContactSearchAssets(), settingsManager: SelectedWalletSettings.shared,
            qrEncoder: ContactSearchCoder(), sharingFactory: ContactSearchShare(), assetsProvider: nil,
            providerFactory: BalanceProviderFactory(accountId: "", cacheFacade: CoreDataCacheFacade.shared, networkOperationFactory: factory, identifierFactory: SingleProviderIdentifierFactory()),
            feeProvider: FeeProvider(account: nil), marketCapService: ContactSearchMarket())
        model.view = view; return (model, network, view, route)
    }
    private func contact(_ address: String) -> SearchData { SearchData(accountId: address, firstName: address, lastName: "") }
    private func titles(_ rows: [SoramitsuTableViewItemProtocol]) -> [String] { rows.compactMap { ($0 as? ContactCellItem)?.title } }
    func testContactSearchDebouncesEditsAndUsesTheLatestPattern() async {
        let (model, source, _, _) = fixture(); model.search("first"); model.search("second"); model.search("third"); await pause(600)
        XCTAssertEqual(source.queries, ["third"])
    }
    func testClearingSearchCancelsTheScheduledReadAndShowsRecentRows() async {
        let (model, source, _, _) = fixture(); model.recentContantsItems = [ContactCellItem(title: "recent")]; var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }
        model.search("query"); model.search(""); await pause(600); XCTAssertTrue(source.queries.isEmpty); XCTAssertEqual(titles(rows), ["recent"])
    }
    func testClearingSearchCancelsActiveReadAndIgnoresItsLateCompletion() async {
        let (model, source, _, _) = fixture(); model.recentContantsItems = [ContactCellItem(title: "recent")]; var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }
        model.search("query"); await pause(600); model.search(""); source.completions[0](.success([contact("stale")])); await pause()
        XCTAssertEqual(source.calls[0].cancellations, 1); XCTAssertEqual(titles(rows), ["recent"])
    }
    func testOlderSearchCannotReplaceTheLatestResults() async {
        let (model, source, _, _) = fixture(); var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }
        model.search("first"); await pause(600); model.search("second"); await pause(600)
        source.completions[1](.success([contact("current")])); source.completions[0](.success([contact("stale")])); await pause(); XCTAssertEqual(titles(rows), ["current"])
    }
    func testRepeatingAQueryDoesNotReadmitTheCancelledRequestsResponse() async {
        let (model, source, _, _) = fixture(); var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }
        model.search("same"); await pause(600); model.search("other"); model.search("same"); await pause(600)
        source.completions[1](.success([contact("current")])); source.completions[0](.success([contact("obsolete")])); await pause()
        XCTAssertEqual(titles(rows), ["current"])
    }
    func testCancellingAReadCannotDeliverItsReentrantCompletion() async {
        let (model, source, _, _) = fixture(); var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }
        model.search("same"); await pause(600); source.calls[0].onCancel = { source.completions[0](.success([self.contact("obsolete")])) }
        model.search("same"); await pause(); XCTAssertFalse(titles(rows).contains("obsolete")); model.search("")
    }
    func testContactSearchTrimsPastedAddressWhitespace() async {
        let (model, source, _, _) = fixture(); model.search("  recipient\n"); await pause(600); XCTAssertEqual(source.queries, ["recipient"])
    }
    func testEmptySearchResultRestoresTheRecentContacts() async {
        let (model, source, _, _) = fixture(); model.recentContantsItems = [ContactCellItem(title: "recent")]; var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }
        model.search("empty"); await pause(600); source.completions[0](.success(nil)); await pause(); XCTAssertEqual(titles(rows), ["recent"])
    }
    func testContactSearchPublishesBackgroundCompletionOnMain() async {
        let (model, source, _, _) = fixture(); let shown = expectation(description: "main results"); model.setupItems = { _ in XCTAssertTrue(Thread.isMainThread); shown.fulfill() }
        model.search("query"); await pause(600); let completion = source.completions[0]; DispatchQueue.global().async { completion(.success([SearchData(accountId: "receiver", firstName: "receiver", lastName: "")])) }
        await fulfillment(of: [shown], timeout: 2)
    }
    func testContactRowRoutesItsCurrentRecipientWithoutSending() async throws {
        let (model, source, view, _) = fixture(); var result: ScanQRResult?; var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }; model.completion = { result = $0 }
        model.search("query"); await pause(600); source.completions[0](.success([contact("recipient")])); await pause()
        try XCTUnwrap(rows.compactMap { $0 as? ContactCellItem }.first).itemActionTap(with: nil)
        XCTAssertEqual(view.dismissals, 1); XCTAssertEqual(result?.firstName, "recipient")
    }
    func testContactScannerResultUsesTheProvidedRecipient() {
        let (model, _, view, route) = fixture(); var result: ScanQRResult?; model.completion = { result = $0 }; model.openQR(); route.completion?(ScanQRResult(firstName: "scanned"))
        XCTAssertEqual(route.opens, 1); XCTAssertEqual(view.dismissals, 1); XCTAssertEqual(result?.firstName, "scanned")
    }
    func testContactScreenForwardsEditsAndClearOrScanActions() {
        let model = ContactScreenModel(); let view = ContactsViewController(viewModel: model); view.loadViewIfNeeded(); XCTAssertEqual(model.loads, 1)
        view.field.button.sendActions(for: .touchUpInside); XCTAssertEqual(model.scans, 1)
        view.field.textField.text = "recipient"; view.field.textField.sendActions(for: .editingChanged); XCTAssertEqual(model.queries, ["recipient"])
        view.field.button.sendActions(for: .touchUpInside); XCTAssertEqual(model.queries, ["recipient", ""]); XCTAssertEqual(model.scans, 1); XCTAssertEqual(view.field.textField.text, "")
    }
    func testContactScreenClearsValidationWhenTheAddressChanges() {
        let model = ContactScreenModel(); let view = ContactsViewController(viewModel: model); view.loadViewIfNeeded(); view.show(error: "Invalid recipient")
        XCTAssertEqual(view.field.sora.state, .fail); view.field.textField.text = "new"; view.field.textField.sendActions(for: .editingChanged); XCTAssertNotEqual(view.field.sora.state, .fail)
        XCTAssertEqual(view.field.textField.autocorrectionType, .no); XCTAssertEqual(view.field.textField.autocapitalizationType, .none)
    }
    func testContactScreenRendersPublishedHeaderRecipientAndFooter() async {
        let model = ContactScreenModel(); let view = ContactsViewController(viewModel: model); view.loadViewIfNeeded(); view.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        model.setupItems?([ContactHeaderCellItem(title: "RECENT"), ContactCellItem(title: "receiver"), ContactFooterItem()]); await pause(); view.view.layoutIfNeeded()
        func all(_ root: UIView) -> [UIView] { [root] + root.subviews.flatMap(all) }
        let table = all(view.view).compactMap { $0 as? SoramitsuTableView }.first; XCTAssertEqual(table?.numberOfRows(inSection: 0), 3)
        XCTAssertTrue(all(view.view).compactMap { $0 as? UILabel }.contains { $0.text == "receiver" })
    }
    private func selectedAccount() -> AccountItem {
        AccountItem(address: "current-wallet", cryptoType: .sr25519, networkType: 69, username: "Current", publicKeyData: Data(repeating: 3, count: 32), settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
    }
    func testInitialContactLoadPublishesCachedRecipientsBetweenHeaderAndFooter() async {
        let (model, _, _, _) = fixture(contacts: [contact("first"), contact("second")]); let shown = expectation(description: "cached contacts")
        var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0; if self.titles(rows) == ["first", "second"] { shown.fulfill() } }
        model.viewDidLoad(); await fulfillment(of: [shown], timeout: 3)
        XCTAssertTrue(rows.first is ContactHeaderCellItem); XCTAssertTrue(rows.last is ContactFooterItem); XCTAssertEqual(rows.count, 4)
    }
    func testRecentRecipientReturnsTheChosenAccountWithoutAnySearchOrSend() async throws {
        let (model, source, view, _) = fixture(contacts: [contact("recipient")]); let shown = expectation(description: "recent row")
        var rows: [SoramitsuTableViewItemProtocol] = [], result: ScanQRResult?
        model.setupItems = { rows = $0; if !self.titles(rows).isEmpty { shown.fulfill() } }; model.completion = { result = $0 }
        model.viewDidLoad(); await fulfillment(of: [shown], timeout: 3)
        try XCTUnwrap(rows.compactMap { $0 as? ContactCellItem }.first).itemActionTap(with: nil)
        XCTAssertEqual(result?.firstName, "recipient"); XCTAssertEqual(view.dismissals, 1); XCTAssertTrue(source.queries.isEmpty)
    }
    func testRecentRecipientRechecksTheCurrentWalletAtSelectionTime() async throws {
        let (model, _, view, _) = fixture(contacts: [contact("current-wallet")]); let shown = expectation(description: "recent row")
        var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0; if !self.titles(rows).isEmpty { shown.fulfill() } }
        model.completion = { _ in XCTFail("Cannot send to the current wallet") }
        model.viewDidLoad(); await fulfillment(of: [shown], timeout: 3)
        SelectedWalletSettings.shared.commitInternalValue(selectedAccount())
        try XCTUnwrap(rows.compactMap { $0 as? ContactCellItem }.first).itemActionTap(with: nil)
        XCTAssertEqual(view.errors.count, 1); XCTAssertEqual(view.dismissals, 0)
    }
    func testScannerCannotReturnTheCurrentWalletAsItsOwnRecipient() {
        let (model, _, view, route) = fixture(); SelectedWalletSettings.shared.commitInternalValue(selectedAccount())
        model.completion = { _ in XCTFail("Cannot send to the current wallet") }; model.openQR(); route.completion?(ScanQRResult(firstName: "current-wallet"))
        XCTAssertEqual(view.errors.count, 1); XCTAssertEqual(view.dismissals, 0)
    }
    func testSearchFiltersTheSelectedAccountOutOfServerResults() async {
        let (model, source, _, _) = fixture(); SelectedWalletSettings.shared.commitInternalValue(selectedAccount()); var rows: [SoramitsuTableViewItemProtocol] = []
        model.setupItems = { rows = $0 }; model.search("wallet"); await pause(600)
        source.completions[0](.success([contact("current-wallet"), contact("recipient")])); await pause()
        XCTAssertEqual(titles(rows), ["recipient"])
    }
    func testRemoteRowRechecksASelectionChangeBeforeReturningItsRecipient() async throws {
        let (model, source, view, _) = fixture(); var rows: [SoramitsuTableViewItemProtocol] = []
        model.setupItems = { rows = $0 }; model.search("wallet"); await pause(600); source.completions[0](.success([contact("current-wallet")])); await pause()
        SelectedWalletSettings.shared.commitInternalValue(selectedAccount())
        try XCTUnwrap(rows.compactMap { $0 as? ContactCellItem }.first).itemActionTap(with: nil)
        XCTAssertEqual(view.errors.count, 1); XCTAssertEqual(view.dismissals, 0)
    }
    func testLocalAddressMatchPublishesImmediatelyWithoutAServerLookup() async throws {
        let local = ContactLocalMatches(), (model, source, view, _) = fixture(local: local)
        local.results = [ContactViewModel(firstName: "local-recipient", lastName: "", accountId: "0102", image: nil, name: "Local recipient")]
        var rows: [SoramitsuTableViewItemProtocol] = [], result: ScanQRResult?
        model.setupItems = { rows = $0 }; model.completion = { result = $0 }; model.search(" local-recipient ")
        XCTAssertEqual(titles(rows), ["local-recipient"]); XCTAssertEqual(local.queries, ["local-recipient"])
        try XCTUnwrap(rows.compactMap { $0 as? ContactCellItem }.first).itemActionTap(with: nil)
        XCTAssertEqual(result?.firstName, "local-recipient"); XCTAssertEqual(view.dismissals, 1)
        await pause(600); XCTAssertTrue(source.queries.isEmpty)
    }
    func testAuthoritativeEmptyLocalResultDoesNotFallBackToRemoteSearch() async {
        let local = ContactLocalMatches(), (model, source, _, _) = fixture(local: local); local.results = []
        var rows: [SoramitsuTableViewItemProtocol] = []; model.setupItems = { rows = $0 }; model.search("self")
        XCTAssertTrue(titles(rows).isEmpty); XCTAssertEqual(rows.count, 2); await pause(600); XCTAssertTrue(source.queries.isEmpty)
    }
    func testFailedRemoteSearchDoesNotReplacePreviouslyVisibleContacts() async {
        let (model, source, _, _) = fixture(); var updates = 0; model.setupItems = { _ in updates += 1 }
        model.search("query"); await pause(600); source.completions[0](.failure(NSError(domain: "fixture", code: 1))); await pause()
        XCTAssertEqual(updates, 0)
    }
}
private final class ContactSearchView: UIViewController, ContactsViewProtocol {
    var controller: UIViewController { self }; var dismissals = 0; var errors: [String] = []
    func show(error: String) { errors.append(error) }
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; completion?() }
}
private final class ContactScreenModel: ContactsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?; var loads = 0; var scans = 0; var queries: [String] = []
    func viewDidLoad() { loads += 1 }; func search(_ pattern: String) { queries.append(pattern) }; func openQR() { scans += 1 }
}
private final class ContactSearchRoutes: ContactsWireframeProtocol {
    var opens = 0; var completion: ((ScanQRResult) -> Void)?
    func showScanQR(on view: UIViewController?, networkFacade: WalletNetworkOperationFactoryProtocol, assetManager: AssetManagerProtocol, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, assetsProvider: AssetProviderProtocol?, providerFactory: BalanceProviderFactory, feeProvider: FeeProviderProtocol, marketCapService: MarketCapServiceProtocol, completion: ((ScanQRResult) -> Void)?) { opens += 1; self.completion = completion }
}
private final class ContactSearchAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []; func assetInfo(for identifier: String) -> AssetInfo? { nil }; func getAssetList() -> [AssetInfo]? { [] }
    func updateAssetList(_ list: [AssetInfo]) {}; func saveAssetList(_ list: [AssetInfo]) {}; func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }; func visibleCount() -> UInt { 0 }; func setup(for accountSettings: SelectedWalletSettings) {}
}
private struct ContactSearchCoder: WalletQREncoderProtocol { func encode(receiverInfo: ReceiveInfo) throws -> Data { Data() } }
private struct ContactSearchShare: AccountShareFactoryProtocol { func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { [] } }
private final class ContactSearchMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }
private final class ContactSearchCall: CancellableCall { var cancellations = 0; var onCancel: (() -> Void)?; func cancel() { cancellations += 1; onCancel?() } }

private final class ContactSearchService: WalletServiceProtocol {
    var queries: [String] = []; var completions: [SearchCompletionBlock] = []; var calls: [ContactSearchCall] = []
    private let unused = WalletService(operationFactory: WalletNetworkOperationFactoryProtocolMock())
    func search(for searchString: String, runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall {
        queries.append(searchString); completions.append(completionBlock); let call = ContactSearchCall(); calls.append(call); return call
    }
    func fetchBalance(for assets: [String], runCompletionIn queue: DispatchQueue, completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall { unused.fetchBalance(for: assets, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransactionHistory(for filter: WalletHistoryRequest, pagination: Pagination, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall { unused.fetchTransactionHistory(for: filter, pagination: pagination, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransferMetadata(for info: TransferMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransferMetadataCompletionBlock) -> CancellableCall { unused.fetchTransferMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func transfer(info: TransferInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("Contacts attempted a transfer"); return ContactSearchCall() }
    func prepareTransferSubmission(for info: TransferInfo, preSigningValidation: @escaping () throws -> Void) async throws -> PreparedSora2TransferSubmission { XCTFail("Contacts attempted to sign"); throw CancellationError() }
    func submitPreparedTransfer(_ submission: PreparedSora2TransferSubmission, info: TransferInfo, preTransportValidation: @escaping () throws -> Void) async throws -> Data { XCTFail("Contacts attempted a submission"); throw CancellationError() }
    func fetchContacts(runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall { unused.fetchContacts(runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping WithdrawalMetadataCompletionBlock) -> CancellableCall { unused.fetchWithdrawalMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func withdraw(info: WithdrawInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("Contacts attempted withdrawal"); return ContactSearchCall() }
}


    private final class ContactSearchCache: DataProviderRepositoryProtocol {
        typealias Model = SingleValueProviderObject

        private let lock = NSLock()
        private var stored: [String: SingleValueProviderObject] = [:]

        var all: [SingleValueProviderObject] { lock.lock(); defer { lock.unlock() }; return Array(stored.values) }

        func balances(of account: String) -> [BalanceData]? {
            all.first { $0.identifier == account }.flatMap { try? JSONDecoder().decode([BalanceData].self, from: $0.payload) }
        }

        func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[SingleValueProviderObject]> {
            ClosureOperation { self.all }
        }

        func saveOperation(_ updates: @escaping () throws -> [SingleValueProviderObject],
                           _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
            ClosureOperation { [self] in
                let changed = try updates()
                let removed = try deletions()
                lock.lock()
                defer { lock.unlock() }
                removed.forEach { stored[$0] = nil }
                changed.forEach { stored[$0.identifier] = $0 }
            }
        }

        func saveBatchOperation(_ updates: @escaping () throws -> [SingleValueProviderObject],
                                _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
            saveOperation(updates, deletions)
        }

        func fetchOperation(by ids: @escaping () throws -> [String],
                            options _: RepositoryFetchOptions) -> BaseOperation<[SingleValueProviderObject]> {
            ClosureOperation { let selected = try ids(); return self.all.filter { selected.contains($0.identifier) } }
        }

        func fetchOperation(by id: @escaping () throws -> String,
                            options _: RepositoryFetchOptions) -> BaseOperation<SingleValueProviderObject?> {
            ClosureOperation { let selected = try id(); return self.all.first { $0.identifier == selected } }
        }

        func fetchOperation(by _: RepositorySliceRequest,
                            options: RepositoryFetchOptions) -> BaseOperation<[SingleValueProviderObject]> {
            fetchAllOperation(with: options)
        }

        func replaceOperation(_ models: @escaping () throws -> [SingleValueProviderObject]) -> BaseOperation<Void> {
            saveOperation(models, { self.all.map(\.identifier) })
        }

        func deleteAllOperation() -> BaseOperation<Void> { replaceOperation { [] } }
        func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.all.count } }
    }


private final class ContactLocalMatches: ContactsLocalSearchEngineProtocol {
    var results: [ContactViewModelProtocol]?; var queries: [String] = []
    func search(query: String, parameters: ContactModuleParameters, locale: Locale, delegate: ContactViewModelDelegate?) -> [ContactViewModelProtocol]? { queries.append(query); return results }
}

@MainActor
final class LocalContactAddressBoundaryTests: XCTestCase {
    private let account = Data(repeating: 3, count: 32), recipient = Data(repeating: 4, count: 32)
    private func address(_ key: Data, network: SNAddressType = 69) throws -> String { try SS58AddressFactory().addressFromAccountId(data: key, type: network) }
    private func parameters() -> ContactModuleParameters { ContactModuleParameters(accountId: account.toHex(), assetId: WalletAssetId.xor.rawValue) }
    func testSoraAddressResolvesLocallyToTheExactPublicKeyAndIdenticon() throws {
        let factory = ContactsViewModelFactory(dataStorageFacade: UserDataStorageTestFacade()), engine = ContactsLocalSearchEngine(networkType: 69, contactViewModelFactory: factory)
        let expected = try address(recipient), rows = try XCTUnwrap(engine.search(query: expected, parameters: parameters(), locale: Locale(identifier: "en"), delegate: nil))
        let row = try XCTUnwrap(rows.first); XCTAssertEqual(rows.count, 1); XCTAssertEqual(row.accountId, recipient.toHex()); XCTAssertEqual(row.firstName, expected); XCTAssertEqual(row.name, expected); XCTAssertNotNil(row.image)
    }
    func testOwnAddressIsAnAuthoritativeEmptyLocalResult() throws {
        let engine = ContactsLocalSearchEngine(networkType: 69, contactViewModelFactory: ContactsViewModelFactory(dataStorageFacade: UserDataStorageTestFacade()))
        let rows = engine.search(query: try address(account), parameters: parameters(), locale: .current, delegate: nil)
        XCTAssertNotNil(rows); XCTAssertEqual(rows?.count, 0)
    }
    func testMalformedAddressAllowsRemoteSearchInsteadOfInventingAnIdentity() {
        let engine = ContactsLocalSearchEngine(networkType: 69, contactViewModelFactory: ContactsViewModelFactory(dataStorageFacade: UserDataStorageTestFacade()))
        for text in ["", "invalid", "0x01"] { XCTAssertNil(engine.search(query: text, parameters: parameters(), locale: .current, delegate: nil)) }
    }
    func testMalformedOwnerIdentityDoesNotProduceALocalRecipient() throws {
        let engine = ContactsLocalSearchEngine(networkType: 69, contactViewModelFactory: ContactsViewModelFactory(dataStorageFacade: UserDataStorageTestFacade()))
        XCTAssertNil(engine.search(query: try address(recipient), parameters: ContactModuleParameters(accountId: "not-hex", assetId: WalletAssetId.xor.rawValue), locale: .current, delegate: nil))
    }
    func testContactFactoryRejectsItsOwnIdentityAndInvalidAddresses() throws {
        let factory = ContactsViewModelFactory(dataStorageFacade: UserDataStorageTestFacade())
        XCTAssertNil(factory.createContactViewModelFromContact(SearchData(accountId: account.toHex(), firstName: try address(account), lastName: ""), parameters: parameters(), locale: .current, delegate: nil))
        XCTAssertNil(factory.createContactViewModelFromContact(SearchData(accountId: recipient.toHex(), firstName: "invalid-address", lastName: ""), parameters: parameters(), locale: .current, delegate: nil))
    }
}
