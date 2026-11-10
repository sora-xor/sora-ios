// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class AccountOptionsCloudLifecycleTests: XCTestCase {
    private let phrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
    private var previousBackups: [String] = []
    override func setUp() { super.setUp(); previousBackups = ApplicationConfig.shared.backupedAccountAddresses }
    override func tearDown() { ApplicationConfig.shared.backupedAccountAddresses = previousBackups; super.tearDown() }
    private struct Fixture { let interactor: AccountOptionsInteractor; let cloud: OptionsCloud; let keys: InMemoryKeychain; let settings: InMemorySettingsManager; let repository: OptionsAccounts; let account: AccountItem; let keystore: OptionsKeystore; let selection: OptionsSelection; let events: EventCenter; let notifications: NotificationCenter }
    private func make(path: String = "", crypto: CryptoType = .sr25519, customNodes: Bool = false) throws -> Fixture {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager(), cloud = OptionsCloud()
        let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let factory = AccountOperationFactory(keystore: keys, recoveryGate: gate)
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase)
        let op = factory.prepareAccountOperation(request: AccountCreationRequest(username: "Cloud fixture", type: .sora, derivationPath: path, cryptoType: crypto), mnemonic: mnemonic)
        op.main(); let prepared = try XCTUnwrap(op.result).get(); try factory.persistPreparedAccount(prepared)
        let account = prepared.account, repository = OptionsAccounts(items: [account]), facade = UserDataStorageTestFacade()
        let keystore = OptionsKeystore(keys), selection = OptionsSelection(account), events = EventCenter(), notifications = NotificationCenter()
        let chain = ChainModel(chainId: Chain.sora.genesisHash(), name: "SORA", nodes: [], addressPrefix: 69, icon: nil, customNodes: customNodes ? [ChainNodeModel(url: URL(string: "wss://fixture.invalid")!, name: "Fixture", apikey: nil)] : [], iosMinAppVersion: nil)
        let interactor = AccountOptionsInteractor(keystore: keystore, settings: settings, chain: chain, cacheFacade: CoreDataCacheTestFacade(), substrateDataFacade: facade, userDataFacade: facade, account: account, accountRepository: AnyDataProviderRepository(repository), operationManager: OperationManager(), eventCenter: events, mnemonicCreator: IRMnemonicCreator(language: .english), cloudStorageService: cloud, recoveryGate: gate, selectedSettings: selection, notificationCenter: notifications)
        return Fixture(interactor: interactor, cloud: cloud, keys: keys, settings: settings, repository: repository, account: account, keystore: keystore, selection: selection, events: events, notifications: notifications)
    }
    private func prepare(_ f: Fixture, _ authorization: AccountOptionsCloudBackupAuthorization) async -> AccountOptionsCloudBackupPreparation? {
        let done = expectation(description: "sign-in completion"); var result: AccountOptionsCloudBackupPreparation?
        f.interactor.signInToGoogleIfNeeded(authorization: authorization) { value in XCTAssertTrue(Thread.isMainThread); result = value; done.fulfill() }
        await fulfillment(of: [done], timeout: 1); return result
    }
    private func signIn(_ f: Fixture) async -> OpenBackupAccount? {
        let result = await prepare(f, f.interactor.makeCloudBackupAuthorization())
        guard case let .ready(value, _)? = result else { return nil }; return value
    }
    private func passwordAuthorization(_ f: Fixture) async throws -> AccountOptionsCloudBackupAuthorization {
        let result = await prepare(f, f.interactor.makeCloudBackupAuthorization())
        guard case let .ready(_, authorization)? = result else { throw OptionsFailure.offline }
        return authorization
    }
    private func deleteCloudBackup(_ f: Fixture, _ authorization: AccountOptionsCloudBackupAuthorization) async -> Error? {
        let done = expectation(description: "delete completion"); var result: Error?
        f.interactor.deleteBackup(authorization: authorization) { error in XCTAssertTrue(Thread.isMainThread); result = error; done.fulfill() }
        await fulfillment(of: [done], timeout: 1); return result
    }
    private func asksAgain(_ result: AccountOptionsCloudBackupPreparation?) -> Bool { if case .authorizationRequired? = result { return true }; return false }
    private func leaveApp(_ f: Fixture) { f.notifications.post(name: UIApplication.didEnterBackgroundNotification, object: nil) }
    private func otherWallet() -> AccountItem { AccountItem(address: "another-selected-wallet", cryptoType: .sr25519, networkType: 69, username: "Other", publicKeyData: Data(repeating: 2, count: 32), settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 1, isSelected: true) }
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
    func testSuccessfulDeletionRemovesOnlyTheMatchingBackupMarker() async throws { let f = try make(); ApplicationConfig.shared.backupedAccountAddresses = ["keep", f.account.address, f.account.address]; let done = expectation(description: "deleted"); f.interactor.deleteBackup(authorization: f.interactor.makeCloudBackupAuthorization()) { error in XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); done.fulfill() }; await fulfillment(of: [done], timeout: 1); XCTAssertEqual(f.cloud.deleted.map(\.address), [f.account.address]); XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, ["keep"]) }
    func testFailedDeletionPreservesTheBackupMarkerAndReturnsTheError() async throws { let f = try make(); f.cloud.deleteError = OptionsFailure.offline; ApplicationConfig.shared.backupedAccountAddresses = [f.account.address]; let done = expectation(description: "delete failed"); f.interactor.deleteBackup(authorization: f.interactor.makeCloudBackupAuthorization()) { error in XCTAssertTrue(Thread.isMainThread); XCTAssertTrue(error is OptionsFailure); done.fulfill() }; await fulfillment(of: [done], timeout: 1); XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, [f.account.address]) }
    func testRecoveryGateBlocksDeletionBeforeAnyCloudMutation() async throws { let f = try make(); f.settings.setWalletMigrationRecovery(reason: "Fixture recovery required"); let done = expectation(description: "delete refused"); f.interactor.deleteBackup(authorization: f.interactor.makeCloudBackupAuthorization()) { error in XCTAssertNotNil(error); done.fulfill() }; await fulfillment(of: [done], timeout: 1); XCTAssertTrue(f.cloud.deleted.isEmpty) }
    func testLeavingTheAppAfterAuthorizationStopsTheBackupBeforeGoogleSignIn() async throws {
        let f = try make(); let authorization = f.interactor.makeCloudBackupAuthorization(); leaveApp(f)
        let result = await prepare(f, authorization)
        XCTAssertTrue(asksAgain(result)); XCTAssertEqual(f.cloud.signIns, 0); XCTAssertEqual(f.keystore.reads, 0)
    }
    func testLeavingTheAppDuringGoogleSignInStopsTheBackupBeforeThePhraseIsRead() async throws {
        let f = try make(); let notifications = f.notifications
        f.cloud.duringSignIn = { notifications.post(name: UIApplication.didEnterBackgroundNotification, object: nil) }
        let result = await prepare(f, f.interactor.makeCloudBackupAuthorization())
        XCTAssertTrue(asksAgain(result)); XCTAssertEqual(f.cloud.signIns, 1); XCTAssertEqual(f.keystore.reads, 0)
    }
    func testAnotherSelectedWalletStopsTheBackupBeforeThePhraseIsRead() async throws {
        let f = try make(); let authorization = f.interactor.makeCloudBackupAuthorization(); f.selection.currentAccount = otherWallet()
        let result = await prepare(f, authorization)
        XCTAssertTrue(asksAgain(result)); XCTAssertEqual(f.cloud.signIns, 0); XCTAssertEqual(f.keystore.reads, 0)
    }
    func testSelectionChangeRevokesTheAuthorizationEvenWhenTheSameWalletIsSelectedAgain() async throws {
        let f = try make(); let authorization = f.interactor.makeCloudBackupAuthorization()
        let delivered = expectation(description: "selection change delivered")
        f.events.notify(with: SelectedAccountChanged(), completionOnMain: { delivered.fulfill() })
        await fulfillment(of: [delivered], timeout: 1)
        let result = await prepare(f, authorization)
        XCTAssertTrue(asksAgain(result)); XCTAssertEqual(f.cloud.signIns, 0); XCTAssertEqual(f.keystore.reads, 0)
    }
    func testAuthorizationForAnotherWalletCannotReadOrDeleteThisBackup() async throws {
        let f = try make(); let selection = f.selection
        let other = AccountOptionsCloudBackupAuthorization(accountAddress: otherWallet().address, selectedAddress: { selection.currentAccount?.address }, eventCenter: f.events, notificationCenter: f.notifications)
        let result = await prepare(f, other)
        XCTAssertTrue(asksAgain(result)); XCTAssertEqual(f.cloud.signIns, 0); XCTAssertEqual(f.keystore.reads, 0)
        let error = await deleteCloudBackup(f, other)
        XCTAssertEqual(error as? AccountOptionsCloudBackupError, .authorizationRequired); XCTAssertTrue(f.cloud.deleted.isEmpty)
    }
    func testOneAuthorizationReadsThePhraseForOneBackupOnly() async throws {
        let f = try make(); let authorization = f.interactor.makeCloudBackupAuthorization()
        let first = await prepare(f, authorization)
        guard case .ready? = first else { return XCTFail("The authorized backup was not prepared") }
        let reads = f.keystore.reads; XCTAssertGreaterThan(reads, 0)
        let second = await prepare(f, authorization)
        XCTAssertTrue(asksAgain(second)); XCTAssertEqual(f.keystore.reads, reads); XCTAssertEqual(f.cloud.signIns, 1)
    }
    func testThePasswordScreenGetsOneMoreReadForThisAccount() async throws {
        let f = try make(); let next = try await passwordAuthorization(f)
        XCTAssertEqual(next.accountAddress, f.account.address)
        XCTAssertThrowsError(try next.require(for: otherWallet().address)) { XCTAssertEqual($0 as? AccountOptionsCloudBackupError, .authorizationRequired) }
        XCTAssertNoThrow(try next.require(for: f.account.address)); XCTAssertNoThrow(try next.redeem(for: f.account.address))
        XCTAssertThrowsError(try next.redeem(for: f.account.address)) { XCTAssertEqual($0 as? AccountOptionsCloudBackupError, .authorizationRequired) }
    }
    func testLeavingTheAppBeforeThePasswordIsSavedLapsesThePasswordScreenRead() async throws {
        let f = try make(); let next = try await passwordAuthorization(f); leaveApp(f)
        XCTAssertThrowsError(try next.require(for: f.account.address)) { XCTAssertEqual($0 as? AccountOptionsCloudBackupError, .authorizationRequired) }
    }
    func testAnotherSelectedWalletLapsesThePasswordScreenRead() async throws {
        let f = try make(); let next = try await passwordAuthorization(f); f.selection.currentAccount = otherWallet()
        XCTAssertThrowsError(try next.require(for: f.account.address)) { XCTAssertEqual($0 as? AccountOptionsCloudBackupError, .authorizationRequired) }
    }
    func testSelectionChangeLapsesThePasswordScreenReadEvenForTheSameWallet() async throws {
        let f = try make(); let next = try await passwordAuthorization(f)
        let delivered = expectation(description: "selection change delivered")
        f.events.notify(with: SelectedAccountChanged(), completionOnMain: { delivered.fulfill() })
        await fulfillment(of: [delivered], timeout: 1)
        XCTAssertThrowsError(try next.require(for: f.account.address)) { XCTAssertEqual($0 as? AccountOptionsCloudBackupError, .authorizationRequired) }
    }
    func testLeavingTheAppAfterAuthorizationKeepsTheCloudBackup() async throws {
        let f = try make(); ApplicationConfig.shared.backupedAccountAddresses = [f.account.address]
        let authorization = f.interactor.makeCloudBackupAuthorization(); leaveApp(f)
        let error = await deleteCloudBackup(f, authorization)
        XCTAssertEqual(error as? AccountOptionsCloudBackupError, .authorizationRequired)
        XCTAssertTrue(f.cloud.deleted.isEmpty); XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, [f.account.address])
    }
    func testAnotherSelectedWalletKeepsTheCloudBackup() async throws {
        let f = try make(); ApplicationConfig.shared.backupedAccountAddresses = [f.account.address]
        let authorization = f.interactor.makeCloudBackupAuthorization(); f.selection.currentAccount = otherWallet()
        let error = await deleteCloudBackup(f, authorization)
        XCTAssertEqual(error as? AccountOptionsCloudBackupError, .authorizationRequired)
        XCTAssertTrue(f.cloud.deleted.isEmpty); XCTAssertEqual(ApplicationConfig.shared.backupedAccountAddresses, [f.account.address])
    }
    func testOneAuthorizationDeletesTheBackupOnce() async throws {
        let f = try make(); let authorization = f.interactor.makeCloudBackupAuthorization()
        let first = await deleteCloudBackup(f, authorization); XCTAssertNil(first)
        let second = await deleteCloudBackup(f, authorization)
        XCTAssertEqual(second as? AccountOptionsCloudBackupError, .authorizationRequired); XCTAssertEqual(f.cloud.deleted.count, 1)
    }
    func testLastAccountWithCustomNodesIsReportedOnTheMainThread() async throws { let f = try make(customNodes: true); let done = expectation(description: "account count"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertTrue(Thread.isMainThread); XCTAssertTrue(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
    func testLastAccountWithoutCustomNodesDoesNotClaimCustomNodes() async throws { let f = try make(); let done = expectation(description: "account count"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertFalse(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
    func testMultipleAccountsDoNotTriggerTheLastCustomNodeWarning() async throws { let f = try make(customNodes: true); f.repository.items.append(f.account); let done = expectation(description: "account count"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertFalse(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
    func testRepositoryFailureAlwaysCompletesTheCustomNodeCheck() async throws { let f = try make(customNodes: true); f.repository.failure = OptionsFailure.offline; let done = expectation(description: "account read failed"); f.interactor.isLastAccountWithCustomNodes { value in XCTAssertFalse(value); done.fulfill() }; await fulfillment(of: [done], timeout: 1) }
}
private enum OptionsFailure: Error { case offline }
private final class OptionsCloud: CloudStorageServiceProtocol {
    var isUserAuthorized: Bool { true }; var auth: CloudStorageAccountState = .authorized
    var signInError: Error?, listError: Error?, deleteError: Error?; var accounts: [OpenBackupAccount] = [], deleted: [OpenBackupAccount] = []
    var signIns = 0; var duringSignIn: (() -> Void)?
    func signInIfNeeded() async throws -> CloudStorageAccountState { signIns += 1; duringSignIn?(); if let signInError { throw signInError }; return auth }
    func getBackupAccounts() async throws -> [OpenBackupAccount] { if let listError { throw listError }; return accounts }
    func deleteBackup(account: OpenBackupAccount) async throws { if let deleteError { throw deleteError }; deleted.append(account) }
    func saveBackup(account: OpenBackupAccount, password: String) async throws { XCTFail("Unexpected cloud write") }
    func importBackup(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount { XCTFail("Unexpected cloud import"); throw OptionsFailure.offline }
    func disconnect() {}
}
// Counts secret reads; the material itself lives in the wrapped keychain.
private final class OptionsKeystore: KeystoreProtocol {
    let base: InMemoryKeychain; var reads = 0
    init(_ base: InMemoryKeychain) { self.base = base }
    func addKey(_ key: Data, with identifier: String) throws { try base.addKey(key, with: identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try base.updateKey(key, with: identifier) }
    func fetchKey(for identifier: String) throws -> Data { reads += 1; return try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
    func deleteKey(for identifier: String) throws { try base.deleteKey(for: identifier) }
}
private final class OptionsSelection: SelectedWalletSettingsProtocol {
    var currentAccount: AccountItem?
    init(_ account: AccountItem?) { currentAccount = account }
    func performSave(value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected selection save") }
    func performInsertAndSelect(prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected account import") }
    func performSelectAfterRemoval(value: AccountItem, lifecycleLease: WalletLifecycleLease, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected selection change") }
    func performUpdateName(account: AccountItem, displayName: String, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected name write") }
    func performUpdateAssetSettings(account: AccountItem, settings: AccountSettings, completionClosure: @escaping (Result<AccountItem, Error>) -> Void) { XCTFail("Unexpected asset preference write") }
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) { completionClosure(.success(currentAccount)) }
    func save(value: AccountItem) { XCTFail("Unexpected selection save") }
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

final class CloudBackupPreservationBoundaryTests: XCTestCase {
  private let address = String(repeating: "5", count: 48)
  private func folder() -> GTLRDrive_File {
    let value = GTLRDrive_File(); value.identifier = "folder"; value.name = "backupFolder"
    value.mimeType = "application/vnd.google-apps.folder"; return value
  }
  private func list(_ files: [GTLRDrive_File] = [], token: String? = nil) -> GTLRDrive_FileList {
    let value = GTLRDrive_FileList(); value.files = files; value.nextPageToken = token; return value
  }
  private func folderQuery() -> GTLRDriveQuery_FilesList {
    let query = GTLRDriveQuery_FilesList.query(); query.spaces = "appDataFolder"; query.q = "name = 'backupFolder'"; return query
  }
  // Sorted keys: the readback check compares bytes, and dictionary order varies between calls.
  private func payload() throws -> Data { try JSONSerialization.data(withJSONObject: ["address": address, "encoded": "synthetic-encrypted-backup"], options: [.sortedKeys]) }
  private func upload(_ payload: Data? = nil, parents: [String] = ["folder"], name: String? = nil) throws -> GTLRDriveQuery_FilesCreate {
    let file = GTLRDrive_File(); file.name = name ?? "\(address).json"; file.parents = parents
    return GTLRDriveQuery_FilesCreate.query(withObject: file,
      uploadParameters: GTLRUploadParameters(data: try payload ?? self.payload(), mimeType: "application/json"))
  }
  private func file(revision: String = "old", version: Int64 = 1, size: Int? = nil) throws -> GTLRDrive_File {
    let value = GTLRDrive_File(); value.identifier = "backup"; value.name = "\(address).json"
    value.mimeType = "application/json"; value.headRevisionId = revision; value.version = NSNumber(value: version)
    value.size = NSNumber(value: try size ?? payload().count); return value
  }
  private func media(_ data: Data) -> GTLRDataObject { let value = GTLRDataObject(); value.data = data; return value }
  private func revision(_ name: String) -> GTLRDrive_Revision { let value = GTLRDrive_Revision(); value.identifier = name; value.keepForever = true; return value }
  private func rejects(_ query: GTLRQueryProtocol, responses: [Any], error expected: WalletCloudBackupWriteError,
    file: StaticString = #filePath, line: UInt = #line) async -> BoundaryDrive {
    let drive = BoundaryDrive(responses)
    do { _ = try await WalletBackupPreservingGoogleService(base: drive).executeQuery(query); XCTFail("Unverified backup accepted", file: file, line: line) }
    catch let error as WalletCloudBackupWriteError { XCTAssertEqual(String(describing: error), String(describing: expected), file: file, line: line) }
    catch { XCTFail("Unexpected error: \(error)", file: file, line: line) }
    XCTAssertFalse(drive.queries.contains { $0 is GTLRDriveQuery_FilesDelete || $0 is GTLRDriveQuery_RevisionsDelete }, file: file, line: line)
    return drive
  }
  func testBackupFolderRejectsInvalidMetadataAndIdentifiers() async {
    for index in 0..<6 {
      let f = folder()
      switch index { case 0: f.name = "other"; case 1: f.mimeType = "application/json"; case 2: f.trashed = true
      case 3: f.identifier = ""; case 4: f.identifier = "bad\nidentifier"; default: f.identifier = String(repeating: "a", count: 1025) }
      let drive = await rejects(folderQuery(), responses: [list([f])], error: .invalidBackup)
      XCTAssertEqual(drive.queries.count, 1)
    }
  }
  func testBackupFolderRejectsIncompleteAndOversizedSearchPages() async {
    let incomplete = list(); incomplete.incompleteSearch = true
    for response: Any in [incomplete, list(Array(repeating: folder(), count: 101)), GTLRDrive_File()] {
      let drive = await rejects(folderQuery(), responses: [response], error: .invalidBackup)
      XCTAssertEqual(drive.queries.count, 1)
    }
  }
  func testBackupFolderRejectsDuplicateMatchesAcrossPages() async {
    let drive = await rejects(folderQuery(), responses: [list([folder()], token: "next"), list([folder()])], error: .ambiguous)
    XCTAssertEqual(drive.queries.count, 2)
  }
  func testBackupFolderRejectsRepeatedPageTokens() async {
    let drive = await rejects(folderQuery(), responses: [list(token: "repeat"), list(token: "repeat")], error: .invalidBackup)
    XCTAssertEqual(drive.queries.compactMap { ($0 as? GTLRDriveQuery_FilesList)?.pageToken }, ["repeat"])
  }
  func testBackupFolderRejectsControlCharacterPageTokens() async {
    let drive = await rejects(folderQuery(), responses: [list(token: "unsafe\n")], error: .invalidBackup)
    XCTAssertEqual(drive.queries.count, 1)
  }
  func testBackupFolderStopsAtFourPages() async {
    let drive = await rejects(folderQuery(), responses: (1...4).map { list(token: "page\($0)") }, error: .invalidBackup)
    XCTAssertEqual(drive.queries.count, 4)
  }
  func testBackupFolderReturnsSingleMatchOnFinalPage() async throws {
    let drive = BoundaryDrive([list(token: "next"), list([folder()])])
    let result = try await WalletBackupPreservingGoogleService(base: drive).executeQuery(folderQuery())
    XCTAssertEqual((result.file as? GTLRDrive_FileList)?.files?.map(\.identifier), ["folder"])
    XCTAssertTrue(drive.queries.allSatisfy { ($0 as? GTLRDriveQuery_FilesList)?.pageSize == 100 })
  }
  func testBackupWriterRejectsUnsupportedQueriesWithoutForwardingThem() async {
    let drive = await rejects(GTLRDriveQuery_FilesDelete.query(withFileId: "backup"), responses: [], error: .invalidBackup)
    XCTAssertTrue(drive.queries.isEmpty)
  }
  func testBackupFolderCreationRequiresVerifiedReturnedIdentifier() async {
    let f = folder(); f.parents = ["appDataFolder"]
    let query = GTLRDriveQuery_FilesCreate.query(withObject: f, uploadParameters: nil)
    let drive = await rejects(query, responses: [GTLRDrive_File()], error: .verificationFailed)
    XCTAssertEqual(drive.queries.count, 1)
  }
  func testBackupUploadRejectsWrongIdentityNameAndParentBeforeNetwork() async throws {
    let invalid = [try upload(Data("{}".utf8)), try upload(name: "other.json"), try upload(parents: []),
      try upload(parents: ["a", "b"]), try upload(parents: ["bad\nparent"]), try upload(Data())]
    for query in invalid {
      let drive = await rejects(query, responses: [], error: .invalidBackup); XCTAssertTrue(drive.queries.isEmpty)
    }
  }
  func testBackupReplacementRejectsRevisionChangeBeforePinning() async throws {
    let drive = await rejects(try upload(), responses: [list([try file()]), try file(revision: "changed")], error: .preservationFailed)
    XCTAssertEqual(drive.queries.count, 2)
    XCTAssertFalse(drive.queries.contains { $0 is GTLRDriveQuery_RevisionsUpdate || $0 is GTLRDriveQuery_FilesUpdate })
  }
  func testBackupReplacementRejectsVersionChangeBeforePinning() async throws {
    let drive = await rejects(try upload(), responses: [list([try file()]), try file(version: 2)], error: .preservationFailed)
    XCTAssertEqual(drive.queries.count, 2)
  }
  func testBackupReplacementRejectsOriginalMediaLengthMismatchBeforePinning() async throws {
    let drive = await rejects(try upload(), responses: [list([try file()]), try file(), media(Data([1]))], error: .preservationFailed)
    XCTAssertEqual(drive.queries.count, 3)
    XCTAssertFalse(drive.queries.contains { $0 is GTLRDriveQuery_RevisionsUpdate })
  }
  func testBackupReplacementRejectsEmptyOriginalMedia() async throws {
    let drive = await rejects(try upload(), responses: [list([try file()]), try file(), media(Data())], error: .verificationFailed)
    XCTAssertEqual(drive.queries.count, 3)
  }
  func testBackupReplacementRejectsWrongMetadataIdentity() async throws {
    let wrong = try file(); wrong.identifier = "other-wallet"
    let drive = await rejects(try upload(), responses: [list([try file()]), wrong], error: .verificationFailed)
    XCTAssertEqual(drive.queries.count, 2)
  }
  func testBackupCreateRejectsUnverifiedFinalRevisionAfterReadback() async throws {
    let saved = try file(revision: "new")
    let drive = await rejects(try upload(), responses: [list(), saved, revision("new"), media(try payload()), try file(revision: "changed")], error: .verificationFailed)
    XCTAssertEqual(drive.queries.count, 5)
    XCTAssertEqual(drive.queries.filter { $0 is GTLRDriveQuery_FilesCreate }.count, 1)
  }
  func testBackupCreateRejectsUnpinnedRevision() async throws {
    let unpinned = revision("new"); unpinned.keepForever = false
    let drive = await rejects(try upload(), responses: [list(), try file(revision: "new"), unpinned], error: .verificationFailed)
    XCTAssertEqual(drive.queries.count, 3)
  }
  func testBackupCreateRejectsSavedSizeMismatch() async throws {
    let drive = await rejects(try upload(), responses: [list(), try file(revision: "new", size: 1)], error: .verificationFailed)
    XCTAssertEqual(drive.queries.count, 2)
  }
  func testBackupErrorMessagesExplainPreservationAndBusyStates() {
    XCTAssertTrue(WalletCloudBackupWriteError.userMessage(for: WalletCloudBackupWriteError.ambiguous).contains("Existing backups were kept"))
    XCTAssertTrue(WalletCloudBackupWriteError.userMessage(for: WalletCloudBackupWriteError.preservationFailed).contains("It was not replaced"))
    XCTAssertTrue(WalletCloudBackupWriteError.userMessage(for: WalletCloudBackupWriteError.busy).contains("Wait for it to finish"))
  }
}
private struct BoundaryDriveTicket: GoogleServiceTicket {}
private final class BoundaryDrive: GoogleService {
  var responses: [Any], queries: [GTLRQueryProtocol] = []
  init(_ responses: [Any]) { self.responses = responses }
  func set(authorizer: GTMFetcherAuthorizationProtocol?) {}
  func executeQuery(_ query: GTLRQueryProtocol) async throws -> (ticket: GoogleServiceTicket, file: Any?) {
    queries.append(query)
    guard !responses.isEmpty else { XCTFail("Unexpected Drive request"); throw WalletCloudBackupWriteError.invalidBackup }
    return (BoundaryDriveTicket(), responses.removeFirst())
  }
}
