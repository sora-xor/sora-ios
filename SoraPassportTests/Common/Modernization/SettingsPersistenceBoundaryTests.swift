// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreData
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraKeystore
import XCTest
@testable import SoraPassport

final class SettingsPersistenceBoundaryTests: XCTestCase {
    private let settings = InMemorySettingsManager()
    private func strings() -> [(SettingsKey, (String?) -> Void, () -> String?)] {
        [(.decentralizedId, { self.settings.decentralizedId = $0 }, { self.settings.decentralizedId }),
         (.publicKeyId, { self.settings.publicKeyId = $0 }, { self.settings.publicKeyId }),
         (.invitationCode, { self.settings.invitationCode = $0 }, { self.settings.invitationCode }),
         (.selectedLocalization, { self.settings.selectedLocalization = $0 }, { self.settings.selectedLocalization }),
         (.lastStreamEventId, { self.settings.lastStreamEventId = $0 }, { self.settings.lastStreamEventId }),
         (.streamToken, { self.settings.streamToken = $0 }, { self.settings.streamToken })]
    }
    func testHistoricalStringKeysRemainReadableWithoutMigratingTheirEncoding() {
        for (key, _, read) in strings() {
            settings.set(value: "Legacy value 日本語", for: key.rawValue)
            XCTAssertEqual(read(), "Legacy value 日本語", key.rawValue)
        }
    }
    func testChangingAndClearingStringPreferencesUsesPlainValuesAndRemovesOnlyTheChosenKey() {
        settings.set(value: "retained", for: "unrelated-fixture")
        for (key, write, read) in strings() {
            write("Updated value"); XCTAssertEqual(settings.anyValue(for: key.rawValue) as? String, "Updated value")
            write(""); XCTAssertEqual(read(), ""); XCTAssertTrue(settings.allKeys().contains(key.rawValue))
            write(nil); XCTAssertNil(read()); XCTAssertFalse(settings.allKeys().contains(key.rawValue))
        }
        XCTAssertEqual(settings.string(for: "unrelated-fixture"), "retained")
    }
    func testRegistrationRequiresAnIdentifierAndClearsWhenItIsRemoved() {
        XCTAssertFalse(settings.isRegistered); settings.decentralizedId = "public-identity"; XCTAssertTrue(settings.isRegistered)
        settings.decentralizedId = nil; XCTAssertFalse(settings.isRegistered)
    }
    func testOptionalBooleanPreferencesPreserveTheDifferenceBetweenFalseAndAbsent() {
        let fields: [(SettingsKey, (Bool?) -> Void, () -> Bool?)] = [
            (.biometryEnabled, { self.settings.biometryEnabled = $0 }, { self.settings.biometryEnabled }),
            (.disclaimerHidden, { self.settings.disclaimerHidden = $0 }, { self.settings.disclaimerHidden }),
            (.isCheckedInvitation, { self.settings.isCheckedInvitation = $0 }, { self.settings.isCheckedInvitation })]
        for (key, write, read) in fields {
            XCTAssertNil(read())
            for value in [true, false] { write(value); XCTAssertEqual(read(), value); XCTAssertEqual(settings.anyValue(for: key.rawValue) as? Bool, value) }
            write(nil); XCTAssertNil(read()); XCTAssertFalse(settings.allKeys().contains(key.rawValue))
        }
    }
    func testPinThrottleCoordinatesRemainIntegersAndCanBeIndependentlyCleared() {
        settings.failInputPinCount = 3; settings.inputBlockTimeInterval = 1_800_000_000
        XCTAssertEqual(settings.integer(for: SettingsKey.failInputPinCount.rawValue), 3)
        XCTAssertEqual(settings.integer(for: SettingsKey.inputBlockDate.rawValue), 1_800_000_000)
        settings.failInputPinCount = nil; XCTAssertNil(settings.failInputPinCount); XCTAssertEqual(settings.inputBlockTimeInterval, 1_800_000_000)
        settings.inputBlockTimeInterval = nil; XCTAssertNil(settings.inputBlockTimeInterval)
        XCTAssertFalse(settings.allKeys().contains(SettingsKey.inputBlockDate.rawValue))
    }
    func testMigrationCompletionDefaultsToFalseAndPersistsBothTransitions() {
        XCTAssertFalse(settings.hasMigrated); settings.hasMigrated = true; XCTAssertTrue(settings.hasMigrated)
        settings.hasMigrated = false; XCTAssertFalse(settings.hasMigrated)
        XCTAssertEqual(settings.anyValue(for: SettingsKey.hasMigrated.rawValue) as? Bool, false)
    }
    func testLastSuccessfulEndpointRetainsTheExactURLAndRemovalDoesNotAffectOtherPreferences() {
        let endpoint = URL(string: "wss://node.example.org:9944/path?network=sora")!
        settings.lastSuccessfulUrl = endpoint; XCTAssertEqual(settings.lastSuccessfulUrl, endpoint)
        settings.streamToken = "public-test-token"; settings.lastSuccessfulUrl = nil
        XCTAssertNil(settings.lastSuccessfulUrl); XCTAssertEqual(settings.streamToken, "public-test-token")
    }
}

final class AccountAssetPreferenceBoundaryTests: XCTestCase {
    private final class Fixture {
        let facade = UserDataStorageTestFacade()
        let settings = InMemorySettingsManager()
        let queue = OperationQueue()
        lazy var gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        lazy var coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
        lazy var selection = SelectedWalletSettings(storageFacade: facade, operationQueue: queue, legacySettings: settings,
            walletNetworkMetadataSynchronizer: { _, _, _, _ in XCTFail("Asset preferences must not rename the wallet") },
            lifecycleCoordinator: coordinator, recoveryGate: gate)

        func save(_ accounts: [AccountItem]) throws {
            let repository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
            let operation = repository.saveOperation({ accounts }, { [] })
            queue.addOperations([operation], waitUntilFinished: true)
            _ = try XCTUnwrap(operation.result).get()
        }
        func rows() throws -> [AccountItem] {
            let repository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
            let operation = repository.fetchAllOperation(with: RepositoryFetchOptions(includesProperties: true, includesSubentities: true))
            queue.addOperations([operation], waitUntilFinished: true)
            return try XCTUnwrap(operation.result).get()
        }
    }

    private func account(_ byte: UInt8, selected: Bool, name: String = "Preserved account") throws -> AccountItem {
        let key = Data(repeating: byte, count: 32)
        return AccountItem(address: try SS58AddressFactory().address(fromAccountId: key, type: 69), cryptoType: .sr25519,
            networkType: 69, username: name, publicKeyData: key,
            settings: AccountSettings(visibleAssetIds: ["xor"], orderedAssetIds: ["xor", "val"]), order: Int16(byte), isSelected: selected)
    }

    private func update(_ fixture: Fixture, account: AccountItem, settings: AccountSettings) throws -> AccountItem {
        let done = expectation(description: "Asset preferences persisted")
        var outcome: Result<AccountItem, Error>?
        fixture.selection.performUpdateAssetSettings(account: account, settings: settings) { result in
            outcome = result
            let lease = fixture.coordinator.tryAcquire()
            XCTAssertNotNil(lease, "The owned lifecycle lease must be released before completion")
            lease?.release()
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return try XCTUnwrap(outcome).get()
    }

    func testSelectedAccountPreferenceUpdatePreservesIdentityNameAndOtherWalletRows() throws {
        let fixture = Fixture()
        let selected = try account(0x31, selected: true)
        let other = try account(0x32, selected: false)
        try fixture.save([selected, other])
        fixture.settings.set(value: selected, for: SettingsKey.selectedAccount.rawValue)
        let preferences = AccountSettings(visibleAssetIds: ["val", "pswap"], orderedAssetIds: ["pswap", "val", "xor"])
        let changed = try update(fixture, account: selected, settings: preferences)
        XCTAssertEqual(changed.settings, preferences)
        XCTAssertEqual(changed.username, selected.username)
        XCTAssertEqual(changed.publicKeyData, selected.publicKeyData)
        XCTAssertEqual(changed.order, selected.order)
        XCTAssertTrue(changed.isSelected)
        XCTAssertEqual(fixture.settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue), changed)
        let rows = try fixture.rows()
        XCTAssertEqual(rows.first { $0.address == selected.address }, changed)
        XCTAssertEqual(rows.first { $0.address == other.address }, other)
    }

    func testEditingNonselectedWalletDoesNotReplaceSelectedWalletCache() throws {
        let fixture = Fixture()
        let selected = try account(0x33, selected: true)
        let other = try account(0x34, selected: false)
        try fixture.save([selected, other])
        fixture.settings.set(value: selected, for: SettingsKey.selectedAccount.rawValue)
        let preferences = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])
        let changed = try update(fixture, account: other, settings: preferences)
        XCTAssertEqual(changed.settings, preferences)
        XCTAssertFalse(changed.isSelected)
        XCTAssertEqual(fixture.settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue), selected)
        XCTAssertEqual(try fixture.rows().first { $0.address == other.address }, changed)
    }

    func testClearingOverridesPersistsNilInsteadOfAnEmptyAssetList() throws {
        let fixture = Fixture()
        let selected = try account(0x35, selected: true)
        try fixture.save([selected])
        let changed = try update(fixture, account: selected, settings: AccountSettings(visibleAssetIds: nil, orderedAssetIds: nil))
        XCTAssertNil(changed.settings.visibleAssetIds)
        XCTAssertNil(changed.settings.orderedAssetIds)
        XCTAssertEqual(try fixture.rows(), [changed])
    }

    func testMissingSelectedAccountRejectsPreferenceWriteAndPreservesRows() throws {
        let fixture = Fixture()
        let unselected = try account(0x36, selected: false)
        try fixture.save([unselected])
        XCTAssertThrowsError(try update(fixture, account: unselected, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []))) { error in
            guard case SelectedWalletSettingsError.missingSelectedAccount = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try fixture.rows(), [unselected])
    }

    func testMultipleSelectedAccountsRejectPreferenceWriteAndPreserveBothRows() throws {
        let fixture = Fixture()
        let first = try account(0x37, selected: true)
        let second = try account(0x38, selected: true)
        try fixture.save([first, second])
        XCTAssertThrowsError(try update(fixture, account: first, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []))) { error in
            guard case SelectedWalletSettingsError.multipleSelectedAccounts = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try fixture.rows().sorted { $0.order < $1.order }, [first, second])
    }

    func testStaleCallerCannotOverwriteRenamedAccountWhenChangingAssetPreferences() throws {
        let fixture = Fixture()
        let stale = try account(0x39, selected: true, name: "Old name")
        let current = try account(0x39, selected: true, name: "Current name 日本語")
        try fixture.save([current])
        let changed = try update(fixture, account: stale, settings: AccountSettings(visibleAssetIds: ["pswap"], orderedAssetIds: nil))
        XCTAssertEqual(changed.username, current.username)
        XCTAssertEqual(try fixture.rows(), [changed])
    }

    func testAbsentWalletCannotCreateAnAccountThroughAnAssetPreferenceWrite() throws {
        let fixture = Fixture()
        let existing = try account(0x40, selected: true)
        let missing = try account(0x41, selected: false)
        try fixture.save([existing])
        XCTAssertThrowsError(try update(fixture, account: missing, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []))) { error in
            guard case WalletNetworkMigrationError.legacyIdentityMismatch(missing.address) = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try fixture.rows(), [existing])
    }
}

final class CachePersistenceLifecycleTests: XCTestCase {
    private let facade = SubstrateStorageTestFacade()
    private let queue = OperationQueue()
    private func run<T>(_ operation: BaseOperation<T>) throws -> T {
        queue.addOperations([operation], waitUntilFinished: true)
        return try XCTUnwrap(operation.result).get()
    }
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
    private func save(_ contacts: [ContactItem]) throws {
        let repository: CoreDataRepository<ContactItem, CDContactItem> = facade.createRepository()
        _ = try run(repository.saveOperation({ contacts }, { [] }))
    }
    func testContactSaveCreatesOnlyTheRequestedWalletAndPeer() throws {
        let factory = WalletContactOperationFactory(storageFacade: facade, targetAddress: "wallet-a")
        let before = Int64(Date().timeIntervalSince1970)
        try run(factory.saveByAddressOperation("peer"))
        let rows = try run(factory.fetchContactsOperation())
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows.first?.targetAddress, "wallet-a")
        XCTAssertEqual(rows.first?.peerAddress, "peer"); XCTAssertNil(rows.first?.peerName)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(rows.first?.updatedAt), before)
    }
    func testContactRefreshPreservesAnExistingNameAndUpdatesItsTimestamp() throws {
        try save([ContactItem(peerAddress: "peer", peerName: "Alice", targetAddress: "wallet-a", updatedAt: 1)])
        let factory = WalletContactOperationFactory(storageFacade: facade, targetAddress: "wallet-a")
        try run(factory.saveByAddressOperation("peer"))
        let rows = try run(factory.fetchContactsOperation())
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows.first?.peerName, "Alice")
        XCTAssertGreaterThan(try XCTUnwrap(rows.first?.updatedAt), 1)
    }
    func testTheSamePeerUnderAnotherWalletCannotRenameThisWalletsContact() throws {
        try save([ContactItem(peerAddress: "peer", peerName: "First wallet name", targetAddress: "wallet-a", updatedAt: 1),
                  ContactItem(peerAddress: "peer", peerName: "Second wallet name", targetAddress: "wallet-b", updatedAt: 2)])
        let first = WalletContactOperationFactory(storageFacade: facade, targetAddress: "wallet-a")
        let second = WalletContactOperationFactory(storageFacade: facade, targetAddress: "wallet-b")
        try run(first.saveByAddressOperation("peer"))
        XCTAssertEqual(try run(first.fetchContactsOperation()).map(\.peerName), ["First wallet name"])
        let other = try run(second.fetchContactsOperation())
        XCTAssertEqual(other.map(\.peerName), ["Second wallet name"]); XCTAssertEqual(other.first?.updatedAt, 2)
    }
    func testContactFetchOrdersNewestFirstAndExcludesOtherWallets() throws {
        try save([ContactItem(peerAddress: "old", peerName: nil, targetAddress: "wallet-a", updatedAt: 1),
                  ContactItem(peerAddress: "recent", peerName: "Recent", targetAddress: "wallet-a", updatedAt: 3),
                  ContactItem(peerAddress: "foreign", peerName: nil, targetAddress: "wallet-b", updatedAt: 4)])
        let factory = WalletContactOperationFactory(storageFacade: facade, targetAddress: "wallet-a")
        XCTAssertEqual(try run(factory.fetchContactsOperation()).map(\.peerAddress), ["recent", "old"])
    }
    func testEmptyWalletContactFetchDoesNotInventAContact() throws {
        XCTAssertTrue(try run(WalletContactOperationFactory(storageFacade: facade, targetAddress: "empty").fetchContactsOperation()).isEmpty)
    }
    private func pool(_ id: String = "pool-a", favorite: Bool = true) -> PoolInfo {
        PoolInfo(baseAssetId: "xor", targetAssetId: "val", poolId: id, isFavorite: favorite, accountId: "wallet-a",
            yourPoolShare: 7, baseAssetPooledByAccount: 8, targetAssetPooledByAccount: 9,
            baseAssetPooledTotal: 10, targetAssetPooledTotal: 11, totalIssuances: 12,
            baseAssetReserves: 13, targetAssetReserves: 14, accountPoolBalance: 15)
    }
    func testPoolCacheRoundTripRetainsIdentityAndFavoriteWithoutPersistingLiveBalances() throws {
        let repository = PoolRepositoryFactory(storageFacade: facade).createRepository()
        let original = pool()
        _ = try run(repository.saveOperation({ [original] }, { [] }))
        let restored = try XCTUnwrap(run(repository.fetchOperation(by: original.identifier, options: RepositoryFetchOptions())))
        XCTAssertEqual(restored.baseAssetId, "xor"); XCTAssertEqual(restored.targetAssetId, "val")
        XCTAssertEqual(restored.accountId, "wallet-a"); XCTAssertTrue(restored.isFavorite)
        XCTAssertEqual(restored.poolId, "pool-a"); XCTAssertNil(restored.baseAssetReserves)
        XCTAssertNil(restored.yourPoolShare); XCTAssertNil(restored.accountPoolBalance)
    }
    func testChangingPoolFavoritePreservesEveryLiveAmountAndOriginalIdentity() {
        let original = pool(), update = pool("unrelated", favorite: false), changed = original.replacingVisible(update)
        XCTAssertEqual(changed.poolId, original.poolId); XCTAssertEqual(changed.baseAssetId, original.baseAssetId)
        XCTAssertEqual(changed.targetAssetId, original.targetAssetId); XCTAssertEqual(changed.accountId, original.accountId)
        XCTAssertFalse(changed.isFavorite); XCTAssertTrue(original.isFavorite)
        XCTAssertEqual(changed.yourPoolShare, 7); XCTAssertEqual(changed.baseAssetPooledByAccount, 8)
        XCTAssertEqual(changed.targetAssetPooledByAccount, 9); XCTAssertEqual(changed.baseAssetPooledTotal, 10)
        XCTAssertEqual(changed.targetAssetPooledTotal, 11); XCTAssertEqual(changed.totalIssuances, 12)
        XCTAssertEqual(changed.baseAssetReserves, 13); XCTAssertEqual(changed.targetAssetReserves, 14)
        XCTAssertEqual(changed.accountPoolBalance, 15)
    }
    func testPoolIdentityHashDoesNotChangeWhenFavoriteChanges() {
        let original = pool(), changed = pool(favorite: false), other = pool("pool-b")
        XCTAssertEqual(original, changed); XCTAssertNotEqual(original, other)
        XCTAssertEqual(Set([original, changed, other]).count, 2); XCTAssertEqual(original.id, "pool-a")
    }
    func testPoolWireRecordRejectsMissingRequiredIdentityFields() throws {
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pool())) as? [String: Any])
        for key in ["baseAssetId", "targetAssetId", "poolId", "accountId", "isFavorite"] {
            var wire = original; wire.removeValue(forKey: key)
            XCTAssertThrowsError(try JSONDecoder().decode(PoolInfo.self, from: JSONSerialization.data(withJSONObject: wire)))
        }
    }
}

final class PersistentValueLifecycleTests: XCTestCase {
    private final class Subject: SoraPassport.PersistentValueSettings<String> {
        var setups = [(Result<String?, Error>) -> Void]()
        var saves = [(String, (Result<String, Error>) -> Void)]()
        init() { super.init(storageFacade: UserDataStorageTestFacade()) }
        override func performSetup(completionClosure: @escaping (Result<String?, Error>) -> Void) { setups.append(completionClosure) }
        override func performSave(value: String, completionClosure: @escaping (Result<String, Error>) -> Void) { saves.append((value, completionClosure)) }
    }
    func testSetupPublishesTheLoadedValueBeforeCallingItsCompletion() {
        let s = Subject(); XCTAssertFalse(s.hasValue)
        var called = false
        s.setup(runningCompletionIn: nil) { result in
            called = true; XCTAssertEqual(try? result.get(), "loaded"); XCTAssertEqual(s.value, "loaded")
        }
        XCTAssertNil(s.value); XCTAssertFalse(called); s.setups[0](.success("loaded"))
        XCTAssertTrue(called); XCTAssertTrue(s.hasValue)
    }
    func testEmptySuccessfulSetupClearsAnEarlierSnapshot() {
        let s = Subject(); s.commitInternalValue("old"); s.setup(); s.setups[0](.success(nil))
        XCTAssertNil(s.value); XCTAssertFalse(s.hasValue)
    }
    func testFailedSetupKeepsThePreviouslyCommittedValue() {
        let s = Subject(); s.commitInternalValue("preserved"); var failed = false
        s.setup(runningCompletionIn: nil) { if case .failure = $0 { failed = true } }
        s.setups[0](.failure(SoraPassport.PersistentValueSettingsError.missingValue))
        XCTAssertTrue(failed); XCTAssertEqual(s.value, "preserved")
    }
    func testSaveUsesThePersistedResultAndPublishesItBeforeCompletion() {
        let s = Subject(); s.commitInternalValue("old"); var called = false
        s.save(value: "request", runningCompletionIn: nil) { result in
            called = true; XCTAssertEqual(try? result.get(), "normalized"); XCTAssertEqual(s.value, "normalized")
        }
        XCTAssertEqual(s.saves[0].0, "request"); XCTAssertEqual(s.value, "old")
        s.saves[0].1(.success("normalized")); XCTAssertTrue(called)
    }
    func testFailedSaveLeavesThePreviouslyCommittedValueIntact() {
        let s = Subject(); s.commitInternalValue("preserved"); var failed = false
        s.save(value: "new", runningCompletionIn: nil) { if case .failure = $0 { failed = true } }
        s.saves[0].1(.failure(SoraPassport.PersistentValueSettingsError.missingValue))
        XCTAssertTrue(failed); XCTAssertEqual(s.value, "preserved")
    }
    func testConvenienceSaveStillCommitsItsSuccessfulResult() {
        let s = Subject(); s.save(value: "new"); s.saves[0].1(.success("saved"))
        XCTAssertEqual(s.value, "saved"); XCTAssertTrue(s.hasValue)
    }
    func testSetupCompletionUsesItsRequestedQueueAfterPublishingTheValue() async {
        let s = Subject(), queue = DispatchQueue(label: "fixture.settings.setup"), key = DispatchSpecificKey<String>()
        queue.setSpecific(key: key, value: "setup")
        let completed = expectation(description: "setup delivery")
        s.setup(runningCompletionIn: queue) { _ in
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "setup"); XCTAssertEqual(s.value, "loaded"); completed.fulfill()
        }
        s.setups[0](.success("loaded")); await fulfillment(of: [completed], timeout: 3)
    }
    func testSaveCompletionUsesItsRequestedQueueAfterPublishingTheValue() async {
        let s = Subject(), queue = DispatchQueue(label: "fixture.settings.save"), key = DispatchSpecificKey<String>()
        queue.setSpecific(key: key, value: "save")
        let completed = expectation(description: "save delivery")
        s.save(value: "new", runningCompletionIn: queue) { _ in
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "save"); XCTAssertEqual(s.value, "saved"); completed.fulfill()
        }
        s.saves[0].1(.success("saved")); await fulfillment(of: [completed], timeout: 3)
    }
}

extension CachePersistenceLifecycleTests {
    func testPoolRepositoryUpdatesExistingPoolInsteadOfAddingADuplicate() throws {
        let repository = PoolRepositoryFactory(storageFacade: facade).createRepository()
        _ = try run(repository.saveOperation({ [self.pool()] }, { [] }))
        _ = try run(repository.saveOperation({ [self.pool(favorite: false)] }, { [] }))
        let rows = try run(repository.fetchAllOperation(with: RepositoryFetchOptions()))
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows.first?.poolId, "pool-a"); XCTAssertEqual(rows.first?.isFavorite, false)
    }
    func testPoolRepositoryAppliesWalletFilterAndRequestedOrder() throws {
        let all = PoolRepositoryFactory(storageFacade: facade).createRepository()
        let foreign = PoolInfo(baseAssetId: "xor", targetAssetId: "val", poolId: "pool-z", accountId: "wallet-b")
        _ = try run(all.saveOperation({ [self.pool("pool-a"), self.pool("pool-c"), foreign] }, { [] }))
        let scoped = PoolRepositoryFactory(storageFacade: facade).createRepository(for: NSPredicate(format: "%K == %@", #keyPath(CDPoolInfo.accountId), "wallet-a"),
            sortDescriptors: [NSSortDescriptor(key: #keyPath(CDPoolInfo.poolId), ascending: false)])
        XCTAssertEqual(try run(scoped.fetchAllOperation(with: RepositoryFetchOptions())).map(\.poolId), ["pool-c", "pool-a"])
    }
    func testPoolRepositoryRemovalTargetsTheSavedPoolIdentifier() throws {
        let repository = PoolRepositoryFactory(storageFacade: facade).createRepository()
        _ = try run(repository.saveOperation({ [self.pool("keep"), self.pool("remove")] }, { [] }))
        _ = try run(repository.saveOperation({ [] }, { ["remove"] }))
        XCTAssertEqual(try run(repository.fetchAllOperation(with: RepositoryFetchOptions())).map(\.poolId), ["keep"])
    }
}

@MainActor
final class NodeMapperPersistenceBoundaryTests: XCTestCase {
    private func context(_ modelName: String) throws -> NSManagedObjectContext {
        let url = try XCTUnwrap(Bundle.main.url(forResource: modelName, withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
    private let endpoint = URL(string: "wss://node.example.invalid:9944/Rpc?network=sora")!
    func testConnectionRoundTripKeepsEndpointNetworkNameAndSignedOrdering() throws {
        let context = try context("UserDataModel"), mapper = ManagedConnectionItemMapper()
        let row = CDConnectionItem(context: context)
        let original = ManagedConnectionItem(title: "Custom 日本語", url: endpoint, type: 69, order: -3)
        try mapper.populate(entity: row, from: original, using: context)
        try context.save()
        XCTAssertEqual(row.identifier, endpoint.absoluteString)
        XCTAssertEqual(try mapper.transform(entity: row), original)
        XCTAssertEqual(mapper.entityIdentifierFieldName, "identifier")
    }
    func testUpdatingConnectionReplacesOldFieldsWithoutAnotherRow() throws {
        let context = try context("UserDataModel"), mapper = ManagedConnectionItemMapper()
        let row = CDConnectionItem(context: context)
        let old = ManagedConnectionItem(title: "Old", url: endpoint, type: 69, order: 1)
        let changed = ManagedConnectionItem(title: "Renamed", url: endpoint, type: 42, order: 7)
        try mapper.populate(entity: row, from: old, using: context)
        try mapper.populate(entity: row, from: changed, using: context); try context.save()
        XCTAssertEqual(try mapper.transform(entity: row), changed)
        XCTAssertEqual(try context.count(for: NSFetchRequest<CDConnectionItem>(entityName: "CDConnectionItem")), 1)
    }
    func testIncompleteConnectionCannotInventAnEndpointOrTitle() throws {
        let context = try context("UserDataModel"), mapper = ManagedConnectionItemMapper()
        for missingEndpoint in [true, false] {
            let row = CDConnectionItem(context: context)
            row.identifier = missingEndpoint ? nil : endpoint.absoluteString
            row.title = missingEndpoint ? "Present" : nil
            XCTAssertThrowsError(try mapper.transform(entity: row)) {
                XCTAssertTrue($0 is ManagedConnectionItemMapperError)
            }
        }
    }
    func testInvalidConnectionURLIsRejectedWithoutChangingItsStoredText() throws {
        let context = try context("UserDataModel"), row = CDConnectionItem(context: context)
        row.identifier = "https://[invalid"; row.title = "Broken"
        XCTAssertThrowsError(try ManagedConnectionItemMapper().transform(entity: row))
        XCTAssertEqual(row.identifier, "https://[invalid"); XCTAssertEqual(row.title, "Broken")
    }
    func testCustomNodeRoundTripPreservesItsAPIKeyConfiguration() throws {
        let context = try context("SubstrateDataModel"), mapper = ChainNodeModelMapper()
        let row = CDChainNode(context: context)
        let original = ChainNodeModel(url: endpoint, name: "My endpoint", apikey: .init(queryName: "auth", keyName: "fixture-key-name"))
        try mapper.populate(entity: row, from: original, using: context); try context.save()
        XCTAssertEqual(try mapper.transform(entity: row), original)
        XCTAssertEqual(row.apiQueryName, "auth"); XCTAssertEqual(row.apiKeyName, "fixture-key-name")
        XCTAssertEqual(mapper.entityIdentifierFieldName, "url.absoluteString")
    }
    func testChangingToAPublicNodeClearsThePreviousAPIKeyConfiguration() throws {
        let context = try context("SubstrateDataModel"), mapper = ChainNodeModelMapper()
        let row = CDChainNode(context: context)
        try mapper.populate(entity: row, from: ChainNodeModel(url: endpoint, name: "Protected", apikey: .init(queryName: "auth", keyName: "old-key")), using: context)
        let publicNode = ChainNodeModel(url: endpoint, name: "Public", apikey: nil)
        try mapper.populate(entity: row, from: publicNode, using: context)
        XCTAssertNil(row.apiQueryName); XCTAssertNil(row.apiKeyName)
        XCTAssertEqual(try mapper.transform(entity: row), publicNode)
    }
    func testIncompleteCustomNodeCannotInventIdentityFields() throws {
        let context = try context("SubstrateDataModel"), mapper = ChainNodeModelMapper()
        for missingURL in [true, false] {
            let row = CDChainNode(context: context)
            row.url = missingURL ? nil : endpoint; row.name = missingURL ? "Present" : nil
            XCTAssertThrowsError(try mapper.transform(entity: row)) { XCTAssertTrue($0 is ChainNodeMapperError) }
        }
    }
    func testIncompleteAPIKeyConfigurationDoesNotCreateAnAuthenticationParameter() throws {
        let context = try context("SubstrateDataModel"), mapper = ChainNodeModelMapper()
        for missingQuery in [true, false] {
            let row = CDChainNode(context: context); row.url = endpoint; row.name = "Incomplete"
            row.apiQueryName = missingQuery ? nil : "auth"; row.apiKeyName = missingQuery ? "key" : nil
            XCTAssertNil(try mapper.transform(entity: row).apikey)
        }
    }
    func testChainOptionsAndExternalServicesAreReadFromThePersistedRecord() throws {
        let context = try context("SubstrateDataModel"), row = CDChain(context: context)
        row.chainId = "fixture"; row.name = "Fixture"; row.addressPrefix = 69
        row.isEthereumBased = true; row.isTestnet = true; row.hasCrowdloans = true; row.isOrml = true; row.isTipRequired = true
        row.stakingApiType = "staking"; row.stakingApiUrl = endpoint
        row.historyApiType = "history"; row.historyApiUrl = endpoint
        row.crowdloansApiType = "crowdloans"; row.crowdloansApiUrl = endpoint
        let chain = try ChainModelMapper().transform(entity: row)
        XCTAssertEqual(chain.options, [.ethereumBased, .testnet, .crowdloans, .orml, .tipRequired])
        XCTAssertEqual(chain.externalApi?.staking, .init(type: "staking", url: endpoint))
        XCTAssertEqual(chain.externalApi?.history, .init(type: "history", url: endpoint))
        XCTAssertEqual(chain.externalApi?.crowdloans, .init(type: "crowdloans", url: endpoint))
    }
    func testIncompleteExternalServicesStayAbsentWhileACompleteServiceRemains() throws {
        let context = try context("SubstrateDataModel"), row = CDChain(context: context)
        row.chainId = "fixture"; row.name = "Fixture"
        row.stakingApiType = "staking"; row.historyApiUrl = endpoint
        row.crowdloansApiType = "crowdloans"; row.crowdloansApiUrl = endpoint
        let chain = try ChainModelMapper().transform(entity: row)
        XCTAssertNil(chain.externalApi?.staking); XCTAssertNil(chain.externalApi?.history)
        XCTAssertNotNil(chain.externalApi?.crowdloans); XCTAssertNil(chain.options)
    }
    func testIncompleteNodeKeyConfigurationAlsoRemainsAbsentInItsParentChain() throws {
        let context = try context("SubstrateDataModel"), row = CDChain(context: context)
        row.chainId = "fixture"; row.name = "Fixture"
        let node = CDChainNode(context: context); node.url = endpoint; node.name = "Endpoint"; node.apiQueryName = "auth"
        row.nodes = NSSet(object: node)
        let chain = try ChainModelMapper().transform(entity: row)
        XCTAssertEqual(chain.nodes, [ChainNodeModel(url: endpoint, name: "Endpoint", apikey: nil)])
    }
}
