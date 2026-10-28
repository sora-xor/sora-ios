// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraKeystore
import XCTest

@testable import SoraPassport

/// The actual wallet graph is assembled against independent in-memory stores.
/// No signing or node operation is executed during construction.
@MainActor
final class WalletContextAssemblyFlowTests: XCTestCase {
  private var previousLanguage = L10n.sharedLanguage
  override func setUp() {
    super.setUp()
    previousLanguage = L10n.sharedLanguage
  }
  override func tearDown() {
    L10n.sharedLanguage = previousLanguage
    super.tearDown()
  }
  private func make() throws -> ContextAssemblyFixture { try ContextAssemblyFixture() }

  func testAssemblyBuildsTheRealFacadeForTheSelectedPublicIdentity() throws {
    let f = try make()
    let c = try f.context()
    let facade = try XCTUnwrap(c.networkOperationFactory as? WalletNetworkFacade)
    XCTAssertEqual(facade.address, f.account?.address)
    XCTAssertEqual(facade.networkType, f.account?.addressType)
    XCTAssertEqual(facade.accountSettings.accountId, f.settings.accountId)
    XCTAssertTrue(facade.assetManager === f.assets)
  }
  func testAssemblyUsesTheSameConnectionForBalanceAndSwapOperations() throws {
    let f = try make()
    let facade = try f.facade()
    XCTAssertTrue(facade.engine === f.engine)
    XCTAssertTrue(facade.polkaswapNetworkOperationFactory.engine === f.engine)
    let node = try XCTUnwrap(facade.nodeOperationFactory as? WalletNetworkOperationFactory)
    XCTAssertTrue(node.engine === f.engine)
    XCTAssertEqual(f.engine.calls, 0)
  }
  func testAssemblyBindsBothFacadesToTheExactRuntimeProvider() throws {
    let f = try make()
    let facade = try f.facade()
    XCTAssertTrue((facade.runtimeService as? ContextAssemblyRuntime) === f.runtime)
    let node = try XCTUnwrap(facade.nodeOperationFactory as? WalletNetworkOperationFactory)
    XCTAssertTrue((node.runtimeService as? ContextAssemblyRuntime) === f.runtime)
    XCTAssertEqual(f.runtime.reads, 0)
    XCTAssertEqual(f.runtimeLookups, 1)
  }
  func testAssemblyPreservesTheCallerSuppliedKeystoreForSigning() throws {
    let f = try make()
    let facade = try f.facade()
    let node = try XCTUnwrap(facade.nodeOperationFactory as? WalletNetworkOperationFactory)
    let signer = try XCTUnwrap(node.accountSigner as? SigningWrapper)
    XCTAssertTrue(signer.keystore === f.keys)
  }
  func testMissingAccountFailsBeforeLookingUpRuntimeOrTouchingConnection() throws {
    let f = try make()
    f.account = nil
    XCTAssertThrowsError(try f.context()) {
      XCTAssertEqual(String(describing: $0), "missingAccount")
    }
    XCTAssertEqual(f.runtimeLookups, 0)
    XCTAssertEqual(f.engine.calls, 0)
  }
  func testMissingRuntimeProducesAnExplicitFailureWithoutNetworkFallback() throws {
    let f = try make()
    f.availableRuntime = false
    XCTAssertThrowsError(try f.context()) {
      XCTAssertEqual(String(describing: $0), "missingConnection")
    }
    XCTAssertEqual(f.runtimeLookups, 1)
    XCTAssertEqual(f.engine.calls, 0)
  }
  func testSelectionIsReadAtAssemblyTimeRatherThanFactoryCreation() throws {
    let f = try make()
    let factory = f.factory()
    let replacement = try ContextAssemblyFixture.account(byte: 0x31, crypto: .ed25519)
    f.account = replacement
    let c = try factory.createContext(
      connection: f.engine, assetManager: f.assets,
      accountSettings: f.settings, demeterFarmingService: f.farms)
    let facade = try XCTUnwrap(c.networkOperationFactory as? WalletNetworkFacade)
    XCTAssertEqual(facade.address, replacement.address)
    XCTAssertEqual(
      (facade.nodeOperationFactory as? WalletNetworkOperationFactory)?.cryptoType, .ed25519)
  }
  func testOneAssemblyReadsSelectionOnlyOnce() throws {
    let f = try make()
    _ = try f.context()
    XCTAssertEqual(f.accountLookups, 1)
  }
  func testSr25519GraphKeepsItsSignatureType() throws {
    let f = try make()
    let node = try XCTUnwrap(try f.facade().nodeOperationFactory as? WalletNetworkOperationFactory)
    XCTAssertEqual(node.cryptoType, .sr25519)
    XCTAssertNotNil(node.dummySigner)
  }
  func testEd25519GraphKeepsItsSignatureType() throws {
    let f = try make()
    f.account = try ContextAssemblyFixture.account(byte: 0x17, crypto: .ed25519)
    let node = try XCTUnwrap(try f.facade().nodeOperationFactory as? WalletNetworkOperationFactory)
    XCTAssertEqual(node.cryptoType, .ed25519)
  }
  func testEcdsaGraphKeepsItsSignatureType() throws {
    let f = try make()
    f.account = try ContextAssemblyFixture.account(byte: 0x21, crypto: .ecdsa)
    let node = try XCTUnwrap(try f.facade().nodeOperationFactory as? WalletNetworkOperationFactory)
    XCTAssertEqual(node.cryptoType, .ecdsa)
  }
  func testSeparateAssembliesDoNotReuseAnEarlierAccountsFacade() throws {
    let f = try make()
    let old = try f.facade()
    let replacement = try ContextAssemblyFixture.account(byte: 0x45, crypto: .sr25519)
    f.account = replacement
    let new = try f.facade()
    XCTAssertFalse(old === new)
    XCTAssertNotEqual(old.address, new.address)
    XCTAssertEqual(new.address, replacement.address)
  }
  func testConstructedContextUsesTheInjectedLocalizationManager() throws {
    let f = try make()
    let c = try XCTUnwrap(try f.context() as? Resolver)
    XCTAssertTrue(c.localizationManager === f.localization)
    XCTAssertEqual(c.account.accountId, f.settings.accountId)
  }
  func testLocalizationChangeReachesTheConstructedContext() async throws {
    let f = try make()
    let c = try f.context()
    f.localization.selectedLocalization = "ja"
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(L10n.sharedLanguage.rawValue, "ja")
    XCTAssertEqual((c as? Resolver)?.localizationManager?.selectedLocalization, "ja")
  }
  func testLocalizationObserverDoesNotKeepAnUnusedContextAlive() async throws {
    let f = try make()
    var c: CommonWalletContextProtocol? = try f.context()
    weak var observed = c
    c = nil
    f.localization.selectedLocalization = "ja"
    try await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertNil(observed)
  }
  func testInjectedFarmingServiceRemainsBoundToTheFacade() throws {
    let f = try make()
    let facade = try f.facade()
    XCTAssertTrue(facade.demeterFarmingService === f.farms)
    XCTAssertNil(facade.totalPriceAssetId)
  }
  func testAccountUpdateCommandIsCreatedForTheConstructedResolver() throws {
    let f = try make()
    let c = try f.context()
    XCTAssertTrue(c.prepareAccountUpdateCommand() is AccountUpdateCommand)
    XCTAssertTrue(c.prepareLanguageSwitchCommand(with: .japan) is LanguageSwitchCommand)
  }
  func testInMemoryRepositoriesAreInitiallyEmptyAndReadable() async throws {
    let f = try make()
    let facade = try f.facade()
    let accounts = facade.accountsRepository.fetchAllOperation(with: RepositoryFetchOptions())
    let tx = facade.txStorage.fetchAllOperation(with: RepositoryFetchOptions())
    let chain = facade.chainStorage.fetchAllOperation(with: RepositoryFetchOptions())
    let done = expectation(description: "in-memory reads")
    let finish = BlockOperation { done.fulfill() }
    [accounts, tx, chain].forEach { finish.addDependency($0) }
    let queue = OperationQueue()
    queue.qualityOfService = .userInitiated
    [accounts, tx, chain, finish].forEach { queue.addOperation($0) }
    await fulfillment(of: [done], timeout: 3)
    XCTAssertTrue(try XCTUnwrap(accounts.result).get().isEmpty)
    XCTAssertTrue(try XCTUnwrap(tx.result).get().isEmpty)
    XCTAssertTrue(try XCTUnwrap(chain.result).get().isEmpty)
    XCTAssertEqual(f.engine.calls, 0)
  }
}

@MainActor
private final class ContextAssemblyFixture {
  let keys = InMemoryKeychain()
  let engine = ContextAssemblyEngine()
  let runtime = ContextAssemblyRuntime()
  let assets = ContextAssemblyAssets()
  let farms = ContextAssemblyFarms()
  let substrate = SubstrateStorageTestFacade()
  let users = UserDataStorageTestFacade()
  let localization = LocalizationManager(localization: "en", availableLocalizations: ["en", "ja"])!
  let settings: WalletAccountSettings
  var account: AccountItem?
  var availableRuntime = true, accountLookups = 0, runtimeLookups = 0
  init() throws {
    account = try Self.account(byte: 0x42, crypto: .sr25519)
    settings = WalletAccountSettings(
      accountId: Data(repeating: 0x42, count: 32).toHex(), assets: [])
  }
  static func account(byte: UInt8, crypto: SoraPassport.CryptoType) throws -> AccountItem {
    let key = Data(repeating: byte, count: 32)
    return AccountItem(
      address: try SS58AddressFactory().addressFromAccountId(
        data: key, type: SoraPassport.Chain.sora.addressType()),
      cryptoType: crypto, networkType: SoraPassport.Chain.sora.addressType(),
      username: "Public assembly fixture",
      publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
      order: 0, isSelected: true)
  }
  func factory() -> WalletContextFactory {
    WalletContextFactory(
      keychain: keys,
      selectedAccount: { [unowned self] in
        accountLookups += 1
        return account
      },
      runtimeProvider: { [unowned self] in
        runtimeLookups += 1
        return availableRuntime ? runtime : nil
      }, substrateStorage: substrate, accountStorage: users, localizationManager: localization)
  }
  func context() throws -> CommonWalletContextProtocol {
    try factory().createContext(
      connection: engine, assetManager: assets, accountSettings: settings,
      demeterFarmingService: farms)
  }
  func facade() throws -> WalletNetworkFacade {
    try XCTUnwrap(try context().networkOperationFactory as? WalletNetworkFacade)
  }
}
private final class ContextAssemblyRuntime: RuntimeProviderProtocol {
  let chainId = PIIndexerClient.soraMainnetGenesis
  var snapshot: RuntimeSnapshot? { nil }
  var reads = 0
  func setup() {}
  func setupHot() {}
  func replaceTypesUsage(_ usage: ChainModel.TypesUsage) {}
  func cleanup() {}
  func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?)
    -> BaseOperation<RuntimeCoderFactoryProtocol>
  {
    reads += 1
    return ClosureOperation { throw CancellationError() }
  }
}

private final class ContextAssemblyAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [
    AssetInfo(
      id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil,
      displayName: "SORA", visible: true),
    AssetInfo(
      id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil,
      displayName: "Validator", visible: true),
    AssetInfo(
      id: "custom-zero", symbol: "ZERO", chainId: "", precision: 18, icon: nil,
      displayName: "Zero asset", visible: false),
    AssetInfo(
      id: "custom-unknown", symbol: "UNKNOWN", chainId: "", precision: 18, icon: nil,
      displayName: "Unread asset", visible: false),
  ]
  var saved: [[AssetInfo]] = []
  func assetInfo(for identifier: String) -> AssetInfo? {
    assets.first { $0.identifier == identifier }
  }
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) { saved.append(list) }
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { 2 }
  func setup(for accountSettings: SelectedWalletSettings) {}
}

private final class ContextAssemblyFarms: DemeterFarmingServiceProtocol {
  func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
  func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data)
    async throws -> [UserFarm]
  { [] }
  func getAllFarms() async throws -> [Farm] { [] }
  func getFarm(with _: String) -> Farm? { nil }
  func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String)
    async throws -> [Farm]
  { [] }
  func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) {
    completion([])
  }
}

private final class ContextAssemblyEngine: JSONRPCEngine {
  var calls = 0
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    calls += 1
    if method.contains("submit") { XCTFail("No transport is permitted during tab construction") }
    throw URLError(.notConnectedToInternet)
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 { throw URLError(.notConnectedToInternet) }
  func cancelForIdentifier(_ identifier: UInt16) {}
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}
