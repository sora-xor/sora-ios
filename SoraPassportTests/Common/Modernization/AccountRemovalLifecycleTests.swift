// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class AccountRemovalLifecycleTests: XCTestCase {
    private var directories: [URL] = []
    private var previousBackups: [String] = []
    override func setUp() { super.setUp(); previousBackups = ApplicationConfig.shared.backupedAccountAddresses }
    override func tearDown() {
        ApplicationConfig.shared.backupedAccountAddresses = previousBackups
        directories.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }
    private struct Fixture {
        let model: AccountOptionsInteractor
        let accounts: RemovalAccounts
        let keys: InMemoryKeychain
        let settings: InMemorySettingsManager
        let store: WalletNetworkStore
        let selected: RemovalSelection
        let presenter: RemovalPresenter
        let lifecycle: WalletLifecycleCoordinator
        let journals: RemovalJournalState
        let target: AccountItem
        let stop: RemovalStop
        let original: WalletNetworkSnapshot
    }
    private func make(count: Int = 1, selectedIndex: Int = 0, watchOnly: Bool = false,
                      configureJournals: (RemovalJournalState) -> Void = { _ in }) throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        directories.append(directory)
        let settings = InMemorySettingsManager(), keys = InMemoryKeychain()
        let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let lifecycle = WalletLifecycleCoordinator(recoveryGate: gate)
        let factory = AccountOperationFactory(keystore: keys, recoveryGate: gate)
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
        var items: [AccountItem] = []
        for index in 0..<count {
            let operation = factory.prepareAccountOperation(request: AccountCreationRequest(username: "Removal fixture \(index)", type: .sora, derivationPath: index == 0 ? "" : "//fixture/\(index)", cryptoType: .sr25519), mnemonic: mnemonic)
            operation.main(); let prepared = try XCTUnwrap(operation.result).get()
            if !watchOnly { try factory.persistPreparedAccount(prepared) }
            let account = prepared.account
            items.append(AccountItem(address: account.address, cryptoType: account.cryptoType, networkType: account.networkType, username: account.username, publicKeyData: account.publicKeyData, settings: account.settings, order: Int16(index), isSelected: index == selectedIndex))
            if watchOnly { settings.set(value: true, for: "wallet.watchOnly.\(account.address)") }
        }
        let store = try WalletNetworkStore(baseURL: directory, recoveryGate: gate)
        try WalletNetworkModelMigrator(keystore: keys, store: store, settings: settings,
            lifecycleCoordinator: lifecycle, recoveryGate: gate).migrate(accounts: items, selectedAddress: items[selectedIndex].address)
        let original = try XCTUnwrap(store.load())
        settings.set(value: try JSONEncoder().encode(items[selectedIndex]), for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: "keep until final removal", for: "fixture.marker")
        try keys.saveKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        let accounts = RemovalAccounts(items: items), selected = RemovalSelection(), presenter = RemovalPresenter(), stop = RemovalStop()
        let journals = RemovalJournalState(); configureJournals(journals)
        let readers = WalletPendingDeletionJournals(nexus: { try journals.readNexus() }, polkamarkt: { try journals.readPolkamarkt() }, sora2: { try journals.readSora2() }, sora2PredatesSubmissionWindow: { journals.staleSora2 })
        let facade = UserDataStorageTestFacade()
        let model = AccountOptionsInteractor(keystore: keys, settings: settings,
            chain: ChainModel(chainId: Chain.sora.genesisHash(), name: "SORA", nodes: [], addressPrefix: 69, icon: nil, customNodes: [], iosMinAppVersion: nil),
            cacheFacade: CoreDataCacheTestFacade(), substrateDataFacade: facade, userDataFacade: facade,
            account: items[0], accountRepository: AnyDataProviderRepository(accounts), operationManager: OperationManager(), eventCenter: EventCenter(), mnemonicCreator: IRMnemonicCreator(language: .english), cloudStorageService: RemovalCloud(), recoveryGate: gate,
            lifecycleCoordinator: lifecycle, networkStore: { store }, selectedSettings: selected, pendingJournals: readers, stopWalletServices: { stop.count += 1 })
        model.presenter = presenter
        return Fixture(model: model, accounts: accounts, keys: keys, settings: settings, store: store, selected: selected, presenter: presenter, lifecycle: lifecycle, journals: journals, target: items[0], stop: stop, original: original)
    }
    private func remove(_ f: Fixture, expected: RemovalPresenter.Result, file: StaticString = #filePath, line: UInt = #line) async {
        let done = expectation(description: "removal completes")
        f.presenter.completed = { done.fulfill() }
        f.model.logoutAndClean()
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(f.presenter.results, [expected], file: file, line: line)
        let lease = f.lifecycle.tryAcquire(); XCTAssertNotNil(lease, "Removal must release its lifecycle lease", file: file, line: line); lease?.release()
    }
    private func unchanged(_ f: Fixture, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try f.store.load(), f.original, file: file, line: line)
        XCTAssertEqual(f.accounts.saveCount, 0, file: file, line: line)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)), file: file, line: line)
    }
    func testFinalAccountRemovalCommitsEmptyNetworkInventoryBeforeRestart() async throws {
        let f = try make(); ApplicationConfig.shared.backupedAccountAddresses = [f.target.address, "unrelated"]
        await remove(f, expected: .restart)
        XCTAssertTrue(f.accounts.items.isEmpty); let active = try XCTUnwrap(f.store.load())
        XCTAssertTrue(active.wallets.isEmpty); XCTAssertTrue(active.accounts.isEmpty); XCTAssertNil(active.selectedWalletId)
        XCTAssertTrue(f.settings.allKeys().isEmpty); XCTAssertEqual(f.stop.count, 1)
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)))
        XCTAssertFalse(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue))
        XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, ["unrelated"])
    }
    func testRemovingSelectedWalletSelectsRemainingAccountAndRetainsItsKeysAndPIN() async throws {
        let f = try make(count: 2); let remaining = f.accounts.items[1]
        await remove(f, expected: .close)
        XCTAssertEqual(f.accounts.items.map(\.identifier), [remaining.identifier]); XCTAssertTrue(f.accounts.items[0].isSelected)
        XCTAssertEqual(f.selected.removals.map(\.identifier), [remaining.identifier])
        XCTAssertEqual(f.settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)?.identifier, remaining.identifier)
        XCTAssertEqual(try f.store.load()?.selectedWalletId, remaining.identifier)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(remaining.address)))
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue)); XCTAssertEqual(f.stop.count, 0)
    }
    func testRemovingUnselectedWalletPreservesSelection() async throws {
        let f = try make(count: 2, selectedIndex: 1); let selected = f.accounts.items[1]
        await remove(f, expected: .close)
        XCTAssertEqual(f.accounts.items.map(\.identifier), [selected.identifier]); XCTAssertEqual(f.selected.removals.first?.identifier, selected.identifier)
        XCTAssertEqual(try f.store.load()?.selectedWalletId, selected.identifier)
    }
    func testWatchOnlyRemovalDeletesItsMarkerAndRetainsOtherAccount() async throws {
        let f = try make(count: 2, watchOnly: true)
        await remove(f, expected: .close)
        XCTAssertNil(f.settings.anyValue(for: "wallet.watchOnly.\(f.target.address)"))
        XCTAssertTrue(f.settings.bool(for: "wallet.watchOnly.\(f.accounts.items[0].address)") == true)
    }
    func testReadOnlyRemovalPreservesUnprovenKeysAndPIN() async throws {
        let f = try make(); let tag = KeystoreTag.entropyTagForAddress(f.target.address)
        try f.keys.updateKey(Data(repeating: 7, count: 16), with: tag)
        await remove(f, expected: .restart)
        XCTAssertEqual(try f.keys.fetchKey(for: tag), Data(repeating: 7, count: 16)); XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue))
    }
    func testMissingAccountKeysDoNotPreventExplicitReadOnlyRemoval() async throws {
        let f = try make(); try f.keys.deleteWalletMaterial(for: f.target.address)
        await remove(f, expected: .restart)
        XCTAssertTrue(f.accounts.items.isEmpty); XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.pincode.rawValue))
    }
    func testUnreadableNexusJournalBlocksBeforeAnyMutation() async throws {
        let f = try make { $0.nexusError = RemovalFailure.unavailable }
        await remove(f, expected: .blocked); try unchanged(f)
        XCTAssertEqual(f.presenter.messages, [WalletPendingDeletionPreflightError.nexusJournalUnavailable.localizedDescription])
        XCTAssertEqual(f.journals.reads, ["nexus"])
    }
    func testUnreadablePolkamarktJournalBlocksBeforeAnyMutation() async throws {
        let f = try make { $0.polkamarktError = RemovalFailure.unavailable }
        await remove(f, expected: .blocked); try unchanged(f)
        XCTAssertEqual(f.presenter.messages, [WalletPendingDeletionPreflightError.polkamarktJournalUnavailable.localizedDescription])
    }
    func testRecentUnreadableSoraJournalBlocksBeforeAnyMutation() async throws {
        let f = try make { $0.sora2Error = RemovalFailure.unavailable }
        await remove(f, expected: .blocked); try unchanged(f)
        XCTAssertEqual(f.presenter.messages, [WalletPendingDeletionPreflightError.sora2JournalUnavailable.localizedDescription])
    }
    func testOldUnreadableSoraJournalDoesNotBlockRemovalIndefinitely() async throws {
        let f = try make { $0.sora2Error = RemovalFailure.unavailable; $0.staleSora2 = true }
        await remove(f, expected: .restart); XCTAssertTrue(f.accounts.items.isEmpty)
    }
    func testPendingMarketMutationBlocksRemovalWithoutEnteringRecovery() async throws {
        let f = try make(); f.journals.polkamarkt = [market(account: f.target.address, state: .submitted)]
        await remove(f, expected: .blocked); try unchanged(f)
        XCTAssertEqual(f.presenter.messages, [WalletPendingDeletionPreflightError.unresolvedPolkamarktTransaction.localizedDescription])
        XCTAssertNotNil(f.settings.anyValue(for: "fixture.marker"))
    }
    func testAnotherAccountsMarketMutationDoesNotBlockRemoval() async throws {
        let f = try make(); f.journals.polkamarkt = [market(account: "unrelated", state: .submitting)]
        await remove(f, expected: .restart)
    }
    func testFinalizedMarketMutationDoesNotBlockRemoval() async throws {
        let f = try make(); f.journals.polkamarkt = [market(account: f.target.address, state: .finalized)]
        await remove(f, expected: .restart)
    }
    func testRecoveryGateRejectsRemovalBeforeReadingJournals() async throws {
        let f = try make(); f.settings.setWalletMigrationRecovery(reason: "Fixture recovery")
        await remove(f, expected: .restart); XCTAssertTrue(f.journals.reads.isEmpty); XCTAssertEqual(f.accounts.saveCount, 0)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)))
    }
    func testDuplicateInventoryFailsBeforeCommittingRemoval() async throws {
        let f = try make(); f.accounts.items.append(f.target)
        await remove(f, expected: .restart); XCTAssertEqual(f.accounts.saveCount, 0)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)))
    }
    func testMissingTargetFailsBeforeCommittingRemoval() async throws {
        let f = try make(count: 2); f.accounts.items.removeFirst()
        await remove(f, expected: .restart); XCTAssertEqual(f.accounts.saveCount, 0)
    }
    func testRepositoryReadFailurePreservesKeyMaterial() async throws {
        let f = try make(); f.accounts.readError = RemovalFailure.unavailable
        await remove(f, expected: .restart); XCTAssertEqual(f.accounts.saveCount, 0)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)))
    }
    func testRepositoryWriteFailureDoesNotDeleteAnyKeys() async throws {
        let f = try make(); f.accounts.saveError = RemovalFailure.unavailable
        await remove(f, expected: .restart); XCTAssertEqual(f.accounts.items.count, 1)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address))); XCTAssertEqual(f.stop.count, 0)
    }
    func testUncommittedRepositoryDeletionFailsVerificationBeforeKeyRemoval() async throws {
        let f = try make(); f.accounts.ignoreSaves = true
        await remove(f, expected: .restart); XCTAssertEqual(f.accounts.items.count, 1)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)))
    }
    func testLostSelectionWriteDoesNotEraseRemovedWalletKeys() async throws {
        let f = try make(count: 2); f.accounts.ignoreUpdates = true
        await remove(f, expected: .restart)
        XCTAssertFalse(f.accounts.items[0].isSelected); XCTAssertTrue(f.selected.removals.isEmpty)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)))
    }
    func testSelectionFailurePreservesKeysAndRestartsRecovery() async throws {
        let f = try make(count: 2); f.selected.error = RemovalFailure.unavailable
        await remove(f, expected: .restart)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address))); XCTAssertEqual(f.stop.count, 0)
    }
    func testCorruptedMigrationCompletionMetadataBlocksBeforeDeletion() async throws {
        let f = try make(); f.settings.set(value: Data("invalid".utf8), for: SettingsKey.migratedAccountsV1.rawValue)
        await remove(f, expected: .restart); XCTAssertEqual(f.accounts.saveCount, 0)
        XCTAssertTrue(try f.keys.checkKey(for: KeystoreTag.entropyTagForAddress(f.target.address)))
    }
    func testInvalidWatchOnlyMarkerCannotAuthorizeDeletion() async throws {
        let f = try make(); f.settings.set(value: "true", for: "wallet.watchOnly.\(f.target.address)")
        await remove(f, expected: .restart); XCTAssertEqual(f.accounts.saveCount, 0)
    }
    func testNameUpdateUsesTheInjectedSelectedWalletService() async throws {
        let f = try make(); f.model.updateUsername("Updated name")
        XCTAssertEqual(f.selected.names, ["Updated name"]); XCTAssertEqual(f.selected.nameAccounts, [f.target.identifier])
    }
    private func market(account: String, state: PolkamarktPendingState) -> PolkamarktPendingMutation {
        PolkamarktPendingMutation(id: UUID(), account: account, action: "buy_yes", marketIds: [1], createdAt: Date(), updatedAt: Date(), extrinsicHash: "0x" + String(repeating: "ab", count: 32), state: state, finalizedBlock: state == .finalized ? 1 : nil, errorClass: nil)
    }
}
private enum RemovalFailure: Error { case unavailable }
private final class RemovalStop { var count = 0 }
private final class RemovalJournalState {
    var nexus: [NexusPendingTransaction] = [], polkamarkt: [PolkamarktPendingMutation] = [], sora2: [Sora2PendingSubmission] = []
    var nexusError: Error?, polkamarktError: Error?, sora2Error: Error?, staleSora2 = false
    var reads: [String] = []
    func readNexus() throws -> [NexusPendingTransaction] { reads.append("nexus"); if let nexusError { throw nexusError }; return nexus }
    func readPolkamarkt() throws -> [PolkamarktPendingMutation] { reads.append("polkamarkt"); if let polkamarktError { throw polkamarktError }; return polkamarkt }
    func readSora2() throws -> [Sora2PendingSubmission] { reads.append("sora2"); if let sora2Error { throw sora2Error }; return sora2 }
}
private final class RemovalPresenter: AccountOptionsInteractorOutputProtocol {
    enum Result: Equatable { case restart, close, blocked }
    var results: [Result] = [], messages: [String] = [], completed: (() -> Void)?
    func restart() { XCTAssertTrue(Thread.isMainThread); results.append(.restart); completed?() }
    func close() { XCTAssertTrue(Thread.isMainThread); results.append(.close); completed?() }
    func accountDeletionBlocked(message: String) { XCTAssertTrue(Thread.isMainThread); messages.append(message); results.append(.blocked); completed?() }
}
private final class RemovalSelection: SelectedWalletSettingsProtocol {
    var currentAccount: AccountItem?, error: Error?, removals: [AccountItem] = [], names: [String] = [], nameAccounts: [String] = []
    func performSelectAfterRemoval(value: AccountItem, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { removals.append(value); if let error { completionClosure(.failure(error)) } else { currentAccount = value; completionClosure(.success(value)) } }
    func performUpdateName(account: AccountItem, displayName: String, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { names.append(displayName); nameAccounts.append(account.identifier); completionClosure(.success(account)) }
    func performSave(value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected selection save") }
    func performInsertAndSelect(prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected account import") }
    func performUpdateAssetSettings(account: AccountItem, settings: AccountSettings, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected asset preference write") }
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) { completionClosure(.success(currentAccount)) }
    func save(value: AccountItem) { XCTFail("Unexpected selection save") }
}
private final class RemovalAccounts: DataProviderRepositoryProtocol {
    typealias Model = AccountItem
    var items: [Model], readError: Error?, saveError: Error?, saveCount = 0, ignoreSaves = false, ignoreUpdates = false
    init(items: [Model]) { self.items = items }
    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { if let readError = self.readError { throw readError }; return self.items } }
    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { let ids = try ids(); return self.items.filter { ids.contains($0.identifier) } } }
    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<Model?> { ClosureOperation { let id = try id(); return self.items.first { $0.identifier == id } } }
    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[Model]> { fetchAllOperation(with: options) }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.items.count } }
    func saveOperation(_ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> { ClosureOperation {
        let next = try updates(), removed = try deletions(); self.saveCount += 1
        if let saveError = self.saveError { throw saveError }; if self.ignoreSaves { return }
        if !self.ignoreUpdates { for item in next { if let index = self.items.firstIndex(where: { $0.identifier == item.identifier }) { self.items[index] = item } } }
        self.items.removeAll { removed.contains($0.identifier) }
    } }
    func saveBatchOperation(_ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> { saveOperation(updates, deletions) }
    func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> { ClosureOperation { self.items = try models() } }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation { self.items = [] } }
}
private final class RemovalCloud: CloudStorageServiceProtocol {
    var isUserAuthorized: Bool { false }
    func signInIfNeeded() async throws -> CloudStorageAccountState { XCTFail("Unexpected cloud access"); return .notAuthorized }
    func getBackupAccounts() async throws -> [OpenBackupAccount] { XCTFail("Unexpected cloud access"); return [] }
    func deleteBackup(account: OpenBackupAccount) async throws { XCTFail("Unexpected cloud mutation") }
    func saveBackup(account: OpenBackupAccount, password: String) async throws { XCTFail("Unexpected cloud mutation") }
    func importBackup(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount { XCTFail("Unexpected cloud import"); throw RemovalFailure.unavailable }
    func disconnect() {}
}
