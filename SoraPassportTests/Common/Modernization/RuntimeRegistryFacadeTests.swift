// SPDX-License-Identifier: Apache-2.0
import Foundation
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

final class RuntimeRegistryFacadeTests: XCTestCase {
  private func make() -> (RuntimeRegistryService, FacadeRegistry, FacadeRuntime) {
    let registry = FacadeRegistry()
    let provider = FacadeRuntime()
    registry.provider = provider
    return (RuntimeRegistryService(chain: .sora, chainRegistry: registry), registry, provider)
  }
  func testNewServiceStartsInactive() {
    let (s, _, _) = make()
    XCTAssertFalse(s.isActive)
    XCTAssertEqual(s.chain, .sora)
  }
  func testSetupAndThrottleAreIdempotent() {
    let (s, _, _) = make()
    s.setup()
    s.setup()
    XCTAssertTrue(s.isActive)
    s.throttle()
    s.throttle()
    XCTAssertFalse(s.isActive)
  }
  func testUpdatingChainRoutesFutureReadsToTheNewGenesis() {
    let (s, r, _) = make()
    s.update(to: .polkadot, forced: true)
    _ = s.fetchCoderFactoryOperation()
    XCTAssertEqual(s.chain, .polkadot)
    XCTAssertEqual(r.ids.last, SoraPassport.Chain.polkadot.genesisHash())
  }
  func testDefaultRequestUsesTheConfiguredChain() {
    let (s, r, _) = make()
    _ = s.fetchCoderFactoryOperation()
    XCTAssertEqual(r.ids, [SoraPassport.Chain.sora.genesisHash()])
  }
  func testExplicitTimeoutIsForwardedWithoutReplacement() {
    let (s, _, p) = make()
    _ = s.fetchCoderFactoryOperation(with: 0.125, closure: nil)
    XCTAssertEqual(p.timeouts, [0.125])
  }
  func testZeroTimeoutIsNotSilentlyExtended() {
    let (s, _, p) = make()
    _ = s.fetchCoderFactoryOperation(with: 0, closure: nil)
    XCTAssertEqual(p.timeouts, [0])
  }
  func testDefaultTimeoutKeepsTheProtocolDefault() {
    let (s, _, p) = make()
    _ = s.fetchCoderFactoryOperation()
    XCTAssertEqual(p.timeouts, [120])
  }
  func testMetadataOverrideReachesTheRuntimeProvider() throws {
    let (s, _, p) = make()
    var called = false
    _ = s.fetchCoderFactoryOperation(
      with: 1,
      closure: {
        called = true
        throw CancellationError()
      })
    let closure = try XCTUnwrap(p.metadata)
    XCTAssertThrowsError(try closure())
    XCTAssertTrue(called)
  }
  func testFactoryReturnsTheProvidersOperationUnmodified() {
    let (s, _, p) = make()
    XCTAssertTrue(s.fetchCoderFactoryOperation() === p.operation)
  }
  func testExplicitFactoryReturnsTheProvidersOperationUnmodified() {
    let (s, _, p) = make()
    XCTAssertTrue(s.fetchCoderFactoryOperation(with: 3, closure: nil) === p.operation)
  }
  func testMissingProviderProducesAnExplicitDefaultFailure() throws {
    let (s, r, _) = make()
    r.provider = nil
    let op = s.fetchCoderFactoryOperation()
    op.start()
    XCTAssertThrowsError(try XCTUnwrap(op.result).get()) {
      XCTAssertTrue($0 is RuntimeProviderError)
    }
  }
  func testMissingProviderProducesAnExplicitTimedFailure() throws {
    let (s, r, _) = make()
    r.provider = nil
    let op = s.fetchCoderFactoryOperation(with: 1, closure: nil)
    op.start()
    XCTAssertThrowsError(try XCTUnwrap(op.result).get()) {
      XCTAssertTrue($0 is RuntimeProviderError)
    }
  }
  func testMissingProviderHasNoInventedSnapshot() {
    let (s, r, _) = make()
    r.provider = nil
    XCTAssertNil(s.snapshot)
  }
  func testSnapshotLookupUsesTheLatestChain() {
    let (s, r, _) = make()
    s.update(to: .polkadot, forced: false)
    XCTAssertNil(s.snapshot)
    XCTAssertEqual(r.ids.last, SoraPassport.Chain.polkadot.genesisHash())
  }
  func testReplacedProviderIsUsedForTheNextRead() {
    let (s, r, original) = make()
    _ = s.fetchCoderFactoryOperation()
    let replacement = FacadeRuntime()
    r.provider = replacement
    XCTAssertTrue(s.fetchCoderFactoryOperation() === replacement.operation)
    XCTAssertEqual(original.timeouts.count, 1)
    XCTAssertEqual(replacement.timeouts.count, 1)
  }
  func testThrottleDoesNotDiscardTheSelectedChain() {
    let (s, _, _) = make()
    s.update(to: .polkadot, forced: false)
    s.setup()
    s.throttle()
    XCTAssertEqual(s.chain, .polkadot)
  }
}
private final class FacadeRegistry: ChainRegistryProtocol {
  var provider: RuntimeProviderProtocol?, ids = [String]()
  var availableChainIds: Set<ChainModel.Id>? { nil }
  func getConnection(for chainId: ChainModel.Id) -> ChainConnection? { nil }
  func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
    ids.append(chainId)
    return provider
  }
  func getAssetManager(for chainId: ChainModel.Id) -> AssetManagerProtocol {
    fatalError("No asset read expected")
  }
  func getChain(for chainId: ChainModel.Id) -> ChainModel? { nil }
  func getActiveNode(for chainId: ChainModel.Id) -> ChainNodeModel? { nil }
  func subscribeToChians() {}
  func chainsSubscribe(
    _ target: AnyObject, runningInQueue: DispatchQueue,
    updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
  ) {}
  func chainsUnsubscribe(_ target: AnyObject) {}
  func performHotBoot() {}
  func performColdBoot() {}
  func syncUp() {}
}
private final class FacadeRuntime: RuntimeProviderProtocol {
  let chainId = PIIndexerClient.soraMainnetGenesis
  var snapshot: RuntimeSnapshot? { nil }
  var timeouts = [TimeInterval](), metadata: RuntimeMetadataClosure?
  let operation = ClosureOperation<RuntimeCoderFactoryProtocol> { throw CancellationError() }
  func setup() {}
  func setupHot() {}
  func replaceTypesUsage(_ usage: ChainModel.TypesUsage) {}
  func cleanup() {}
  func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?)
    -> BaseOperation<RuntimeCoderFactoryProtocol>
  {
    timeouts.append(timeout)
    metadata = closure
    return operation
  }
}
