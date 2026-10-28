// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class AccountOptionsCloudLifecycleTests: XCTestCase {
    private let phrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
    private var previousBackups: [String] = []
    override func setUp() { super.setUp(); previousBackups = ApplicationConfig.shared.backupedAccountAddresses }
    override func tearDown() { ApplicationConfig.shared.backupedAccountAddresses = previousBackups; super.tearDown() }
    private struct Fixture { let interactor: AccountOptionsInteractor; let cloud: OptionsCloud; let keys: InMemoryKeychain; let settings: InMemorySettingsManager; let repository: OptionsAccounts; let account: AccountItem }
    private func make(path: String = "", crypto: CryptoType = .sr25519, customNodes: Bool = false) throws -> Fixture {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager(), cloud = OptionsCloud()
        let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let factory = AccountOperationFactory(keystore: keys, recoveryGate: gate)
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase)
        let op = factory.prepareAccountOperation(request: AccountCreationRequest(username: "Cloud fixture", type: .sora, derivationPath: path, cryptoType: crypto), mnemonic: mnemonic)
        op.main(); let prepared = try XCTUnwrap(op.result).get(); try factory.persistPreparedAccount(prepared)
        let account = prepared.account, repository = OptionsAccounts(items: [account]), facade = UserDataStorageTestFacade()
        let chain = ChainModel(chainId: Chain.sora.genesisHash(), name: "SORA", nodes: [], addressPrefix: 69, icon: nil, customNodes: customNodes ? [ChainNodeModel(url: URL(string: "wss://fixture.invalid")!, name: "Fixture", apikey: nil)] : [], iosMinAppVersion: nil)
        let interactor = AccountOptionsInteractor(keystore: keys, settings: settings, chain: chain, cacheFacade: CoreDataCacheTestFacade(), substrateDataFacade: facade, userDataFacade: facade, account: account, accountRepository: AnyDataProviderRepository(repository), operationManager: OperationManager(), eventCenter: EventCenter(), mnemonicCreator: IRMnemonicCreator(language: .english), cloudStorageService: cloud, recoveryGate: gate)
        return Fixture(interactor: interactor, cloud: cloud, keys: keys, settings: settings, repository: repository, account: account)
    }
    private func signIn(_ f: Fixture) async -> OpenBackupAccount? {
        let done = expectation(description: "sign-in completion"); var result: OpenBackupAccount?
        f.interactor.signInToGoogleIfNeeded { value in XCTAssertTrue(Thread.isMainThread); result = value; done.fulfill() }
        await fulfillment(of: [done], timeout: 1); return result
    }
    func testMetadataContainsOnlyTheVerifiedRecoveryPhrase() throws { let f = try make(); XCTAssertTrue(f.interactor.accountHasEntropy); XCTAssertEqual(f.interactor.getMetadata()?.mnemonic.joined(separator: " "), phrase); XCTAssertEqual(f.interactor.currentAccount.address, f.account.address) }
    func testMissingEntropyDoesNotExposeUnrelatedBackupMaterial() throws { let f = try make(); try f.keys.deleteKey(for: KeystoreTag.entropyTagForAddress(f.account.address)); XCTAssertFalse(f.interactor.accountHasEntropy); XCTAssertNil(f.interactor.getMetadata()) }
    func testMismatchedEntropyIsNotAdvertisedAsAvailable() throws { let f = try make(); try f.keys.updateKey(Data(repeating: 7, count: 16), with: KeystoreTag.entropyTagForAddress(f.account.address)); XCTAssertFalse(f.interactor.accountHasEntropy); XCTAssertNil(f.interactor.getMetadata()) }
    func testAuthorizedBackupContainsVerifiedPhraseAddressNameAndCrypto() async throws { let f = try make(); let output = await signIn(f); let value = try XCTUnwrap(output); XCTAssertEqual(value.address, f.account.address); XCTAssertEqual(value.name, "Cloud fixture"); XCTAssertEqual(value.passphrase, phrase); XCTAssertEqual(value.cryptoType, CryptoType.sr25519.typeString); XCTAssertEqual(value.substrateDerivationPath, "") }
    func testDerivedWalletBackupRetainsItsExactDerivationPath() async throws { let f = try make(path: "//fixture/1"); let output = await signIn(f); let value = try XCTUnwrap(output); XCTAssertEqual(value.substrateDerivationPath, "//fixture/1"); XCTAssertEqual(value.passphrase, phrase); XCTAssertEqual(value.address, f.account.address) }
    func testBackupPreservesTheSelectedEd25519CryptoScheme() async throws { let f = try make(crypto: .ed25519); let output = await signIn(f); let value = try XCTUnwrap(output); XCTAssertEqual(value.cryptoType, CryptoType.ed25519.typeString) }
    func testRefusedCloudAuthorizationCompletesWithNoAccount() async throws { let f = try make(); f.cloud.auth = .notAuthorized; let output = await signIn(f); XCTAssertNil(output) }
    func testThrownCloudAuthorizationCompletesInsteadOfLeavingTheSpinnerRunning() async throws { let f = try make(); f.cloud.signInError = OptionsFailure.offline; let output = await signIn(f); XCTAssertNil(output) }
    func testCancelledAuthorizationCompletesWithoutACloudAccount() async throws { let f = try make(); f.cloud.signInError = CancellationError(); let output = await signIn(f); XCTAssertNil(output) }
    func testAuthorizedCloudAccountCannotContainAnEmptyRecoveryPhrase() async throws { let f = try make(); try f.keys.deleteKey(for: KeystoreTag.entropyTagForAddress(f.account.address)); let output = await signIn(f); XCTAssertNil(output) }
    func testChangedRecoveryMaterialCannotProduceABackupForTheWrongIdentity() async throws { let f = try make(); try f.keys.updateKey(Data(repeating: 7, count: 16), with: KeystoreTag.entropyTagForAddress(f.account.address)); let output = await signIn(f); XCTAssertNil(output) }
    func testBackupIsRefusedWhileTheInjectedRecoveryGateIsActive() async throws { let f = try make(); f.settings.setWalletMigrationRecovery(reason: "Fixture recovery required"); let output = await signIn(f); XCTAssertNil(output) }
    func testBackupLookupMatchesTheCurrentAddressExactly() async throws { let f = try make(); f.cloud.accounts = [OpenBackupAccount(address: f.account.address)]; let found = await f.interactor.checkCurrentAccountBackedup(); XCTAssertTrue(found) }
    func testAnotherWalletsBackupDoesNotCountForThisWallet() async throws { let f = try make(); f.cloud.accounts = [OpenBackupAccount(address: "different")]; let found = await f.interactor.checkCurrentAccountBackedup(); XCTAssertFalse(found) }
    func testFailedBackupLookupIsNotReportedAsVerified() async throws { let f = try make(); f.cloud.listError = OptionsFailure.offline; let found = await f.interactor.checkCurrentAccountBackedup(); XCTAssertFalse(found) }
    func testSuccessfulDeletionRemovesOnlyTheMatchingBackupMarker() async throws { let f = try make(); ApplicationConfig.shared.backupedAccountAddresses = ["keep", f.account.address, f.account.address]; let done = expectation(description: "deleted"); f.interactor.deleteBackup { error in XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); done.fulfill() }; await fulfillment(of: [done], timeout: 1); XCTAssertEqual(f.cloud.deleted.map(\.address), [f.account.address]); XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, ["keep"]) }
    func testFailedDeletionPreservesTheBackupMarkerAndReturnsTheError() async throws { let f = try make(); f.cloud.deleteError = OptionsFailure.offline; ApplicationConfig.shared.backupedAccountAddresses = [f.account.address]; let done = expectation(description: "delete failed"); f.interactor.deleteBackup { error in XCTAssertTrue(Thread.isMainThread); XCTAssertTrue(error is OptionsFailure); done.fulfill() }; await fulfillment(of: [done], timeout: 1); XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, [f.account.address]) }
    func testRecoveryGateBlocksDeletionBeforeAnyCloudMutation() async throws { let f = try make(); f.settings.setWalletMigrationRecovery(reason: "Fixture recovery required"); let done = expectation(description: "delete refused"); f.interactor.deleteBackup { error in XCTAssertNotNil(error); done.fulfill() }; await fulfillment(of: [done], timeout: 1); XCTAssertTrue(f.cloud.deleted.isEmpty) }
    func testLastAccountWithCustomNodesIsReportedOnTheMainThread() async throws { let f = try make(customNodes: true); let done = expectation(description: "account count"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertTrue(Thread.isMainThread); XCTAssertTrue(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
    func testLastAccountWithoutCustomNodesDoesNotClaimCustomNodes() async throws { let f = try make(); let done = expectation(description: "account count"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertFalse(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
    func testMultipleAccountsDoNotTriggerTheLastCustomNodeWarning() async throws { let f = try make(customNodes: true); f.repository.items.append(f.account); let done = expectation(description: "account count"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertFalse(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
    func testRepositoryFailureAlwaysCompletesTheCustomNodeCheck() async throws { let f = try make(customNodes: true); f.repository.failure = OptionsFailure.offline; let done = expectation(description: "account read failed"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertFalse(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
}
private enum OptionsFailure: Error { case offline }
private final class OptionsCloud: CloudStorageServiceProtocol {
    var isUserAuthorized: Bool { true }; var auth: CloudStorageAccountState = .authorized
    var signInError: Error?, listError: Error?, deleteError: Error?; var accounts: [OpenBackupAccount] = [], deleted: [OpenBackupAccount] = []
    func signInIfNeeded() async throws -> CloudStorageAccountState { if let signInError { throw signInError }; return auth }
    func getBackupAccounts() async throws -> [OpenBackupAccount] { if let listError { throw listError }; return accounts }
    func deleteBackup(account: OpenBackupAccount) async throws { if let deleteError { throw deleteError }; deleted.append(account) }
    func saveBackup(account: OpenBackupAccount, password: String) async throws { XCTFail("Unexpected cloud write") }
    func importBackup(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount { XCTFail("Unexpected cloud import"); throw OptionsFailure.offline }
    func disconnect() {}
}
private final class OptionsAccounts: DataProviderRepositoryProtocol {
    typealias Model = AccountItem
    var items: [Model]; var failure: Error?
    init(items: [Model]) { self.items = items }
    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { if let failure = self.failure { throw failure }; return self.items } }
    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { let ids = try ids(); return self.items.filter { ids.contains($0.address) } } }
    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<Model?> { ClosureOperation { let id = try id(); return self.items.first { $0.address == id } } }
    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[Model]> { fetchAllOperation(with: options) }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.items.count } }
    func saveOperation(_ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> { ClosureOperation { XCTFail("Unexpected account mutation") } }
    func saveBatchOperation(_ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> { saveOperation(updates, deletions) }
    func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> { saveOperation(models, { [] }) }
    func deleteAllOperation() -> BaseOperation<Void> { saveOperation({ [] }, { [] }) }
}
