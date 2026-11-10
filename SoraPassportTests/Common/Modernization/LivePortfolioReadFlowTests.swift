// SPDX-License-Identifier: Apache-2.0
import Foundation
import RobinHood
import SoraKeystore
import XCTest
@testable import SoraPassport

@MainActor
final class LivePortfolioReadFlowTests: XCTestCase {
    private var previousAccount: AccountItem?, previousNexus = false, previousTaira = false
    private var fixtures = [LiveReadFixture]()
    override func setUp() { super.setUp(); previousAccount = SelectedWalletSettings.shared.currentAccount; previousNexus = SettingsManager.shared.nexusEnabled; previousTaira = SettingsManager.shared.isTairaEnabled; SettingsManager.shared.nexusEnabled = false; SettingsManager.shared.isTairaEnabled = false; SelectedWalletSettings.shared.commitInternalValue(LiveReadFixture.account("wallet-a")) }
    override func tearDown() { fixtures.forEach { $0.subject.stop(); $0.reader.release(); $0.prices.release() }; fixtures = []; SelectedWalletSettings.shared.commitInternalValue(previousAccount); SettingsManager.shared.nexusEnabled = previousNexus; SettingsManager.shared.isTairaEnabled = previousTaira; super.tearDown() }
    private func make(cached: Bool = false, store: PortfolioReadStore? = nil, deadline: TimeInterval = 15) -> LiveReadFixture { let f = LiveReadFixture(cached:cached,store:store,deadline:deadline); fixtures.append(f); return f }
    private func wait(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async { for _ in 0..<250 { if predicate(){return}; try? await Task.sleep(nanoseconds:10_000_000) }; XCTFail("Portfolio read did not settle",file:file,line:line) }
    private func settled(_ f: LiveReadFixture) async { await wait { !f.subject.snapshot.isLoading && !f.prices.calls.isEmpty }; try? await Task.sleep(nanoseconds:30_000_000) }
    func testNewSourceShowsLoadingUntilAllWalletsHaveBeenRead() async { let f = make(); f.reader.held = true; f.subject.start(); await wait{f.reader.calls.count == 1}; XCTAssertTrue(f.subject.snapshot.isLoading); f.reader.release(); await settled(f); XCTAssertFalse(f.subject.snapshot.isLoading) }
    func testCachedWalletsAndBalancesAreImmediatelyVisible() { let f = make(cached:true); XCTAssertFalse(f.subject.snapshot.isLoading); XCTAssertEqual(f.subject.snapshot.wallets.map(\.id),["wallet-a"]); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,5) }
    func testEveryStoredWalletIsReadByItsOwnAddress() async { let f = make(); f.repository.accounts.append(LiveReadFixture.account("wallet-b",order:1)); f.subject.start(); await settled(f); XCTAssertEqual(Set(f.reader.calls.map(\.address)),["wallet-a","wallet-b"]); XCTAssertEqual(f.reader.calls.count,2); XCTAssertEqual(f.subject.snapshot.wallets.map(\.isSelected),[true,false]) }
    func testAccountStorageOrderDeterminesVisibleWalletOrder() async { let f = make(); f.repository.accounts = [LiveReadFixture.account("wallet-b",order:2),LiveReadFixture.account("wallet-a",order:1)]; f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.wallets.map(\.id),["wallet-a","wallet-b"]) }
    func testExactRawFreeReservedAndFrozenValuesReachHoldings() async { let f = make(); f.reader.value = .success([f.xor:PortfolioRawBalance(free:10,reserved:2,frozen:3)]); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,12); XCTAssertEqual(f.subject.snapshot.holdings.first?.transferable,7) }
    func testAssetPrecisionAndIdentityArePassedToTheReader() async { let f = make(); f.subject.start(); await settled(f); XCTAssertEqual(f.reader.calls.first?.assets.map(\.id),[f.xor,f.val]); XCTAssertEqual(f.reader.calls.first?.assets.map(\.precision),[18,6]) }
    func testZeroBalancesDoNotCreateHoldingRows() async { let f = make(); f.reader.value = .success([f.xor:.zero]); f.subject.start(); await settled(f); XCTAssertTrue(f.subject.snapshot.holdings.isEmpty); XCTAssertEqual(f.subject.snapshot.wallets.count,1) }
    func testFailedFirstReadShowsUnavailableWalletRatherThanEmptyLiveBalance() async { let f = make(); f.reader.value = .failure(LiveReadError.offline); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.wallets.first?.freshness.state,.partial); XCTAssertEqual(f.subject.snapshot.wallets.first?.freshness.unreachable,[.sora2]); XCTAssertNil(f.cache.reads["wallet-a"]?.lastRead) }
    func testFailedRefreshPreservesTheLastKnownBalance() async { let f = make(cached:true); f.reader.value = .failure(LiveReadError.offline); f.subject.refreshAll(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,5); XCTAssertEqual(f.subject.snapshot.wallets.first?.freshness.state,.partial) }
    func testSuccessfulRetryClearsThePreviousReadFailure() async { let f = make(cached:true); f.cache.reads["wallet-a"]?.failed = [.sora2]; f.subject.refreshAll(); await settled(f); XCTAssertEqual(f.cache.reads["wallet-a"]?.failed,[]); XCTAssertEqual(f.subject.snapshot.wallets.first?.freshness.state,.live) }
    func testRecentCachedBalancesAvoidAnAutomaticStorageRead() async { let f = make(cached:true); f.subject.start(); await settled(f); XCTAssertTrue(f.reader.calls.isEmpty) }
    func testExplicitRefreshBypassesRecentReadBackoff() async { let f = make(cached:true); f.subject.refreshAll(); await settled(f); XCTAssertEqual(f.reader.calls.count,1) }
    func testStaleCachedBalancesAreRefreshedWhenStarted() async { let f = make(cached:true); f.cache.reads["wallet-a"]?.lastAttempt = Date(timeIntervalSinceNow:-120); f.subject.start(); await settled(f); XCTAssertEqual(f.reader.calls.count,1) }
    func testRepeatedStartDoesNotDuplicateTheInFlightRead() async { let f = make(); f.reader.held = true; f.subject.start(); f.subject.start(); f.subject.start(); await wait{f.reader.calls.count == 1}; f.reader.release(); await settled(f); XCTAssertEqual(f.reader.calls.count,1) }
    func testConcurrentForceRefreshRequestsCoalesceIntoOneFollowUp() async { let f = make(); f.reader.held = true; f.subject.refreshAll(); await wait{f.reader.calls.count == 1}; f.subject.refreshAll(); f.subject.refreshAll(); f.reader.release(); await wait{f.reader.calls.count == 2}; try? await Task.sleep(nanoseconds:30_000_000); XCTAssertEqual(f.reader.calls.count,2) }
    func testBalanceEventRefreshesTheSelectedWalletImmediately() async { let f = make(cached:true); f.subject.start(); await settled(f); f.subject.processBalanceChanged(event:WalletBalanceChanged()); await wait{f.reader.calls.count == 1}; XCTAssertEqual(f.reader.calls.first?.address,"wallet-a") }
    func testBalanceEventDoesNotRefreshRecentUnselectedWallets() async { let f = make(cached:true); f.repository.accounts.append(LiveReadFixture.account("wallet-b",order:1)); f.cache.reads["wallet-b"] = f.cache.reads["wallet-a"]; f.subject.start(); await settled(f); f.subject.processBalanceChanged(event:WalletBalanceChanged()); await wait{f.reader.calls.count == 1}; XCTAssertEqual(f.reader.calls.map(\.address),["wallet-a"]) }
    func testBalanceEventDuringAnInFlightReadIsNotLost() async { let f = make(); f.reader.held = true; f.subject.start(); await wait{f.reader.calls.count == 1}; f.subject.processBalanceChanged(event:WalletBalanceChanged()); try? await Task.sleep(nanoseconds:30_000_000); f.reader.release(); await wait{f.reader.calls.count == 2}; XCTAssertEqual(f.reader.calls.count,2) }
    func testStoppedSourceDoesNotReadOnBalanceEvents() async { let f = make(cached:true); f.subject.start(); await settled(f); f.subject.stop(); f.subject.processBalanceChanged(event:WalletBalanceChanged()); try? await Task.sleep(nanoseconds:40_000_000); XCTAssertTrue(f.reader.calls.isEmpty) }
    func testRestartConsumesBalanceChangesReceivedWhileStopped() async { let f = make(cached:true); f.subject.start(); await settled(f); f.subject.stop(); f.subject.processBalanceChanged(event:WalletBalanceChanged()); try? await Task.sleep(nanoseconds:20_000_000); f.subject.start(); await wait{f.reader.calls.count == 1} }
    func testRepositoryFailurePreservesAlreadyKnownWallets() async { let f = make(cached:true); f.repository.failure = LiveReadError.offline; f.subject.refreshAll(); await wait { f.repository.fetches == 1 }; try? await Task.sleep(nanoseconds:40_000_000); XCTAssertEqual(f.subject.snapshot.wallets.map(\.id),["wallet-a"]); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,5) }
    func testAuthoritativeEmptyRepositoryRemovesDeletedWallets() async { let f = make(cached:true); f.repository.accounts = []; f.subject.refreshAll(); await settled(f); XCTAssertTrue(f.subject.snapshot.wallets.isEmpty); XCTAssertTrue(f.subject.snapshot.holdings.isEmpty) }
    func testRepositoryReadDoesNotWriteWalletMetadata() async { let f = make(); f.subject.start(); await settled(f); XCTAssertEqual(f.repository.writes,0) }
    func testPriceRequestsIncludeOnlyHeldAssetsAndNativeXor() async { let f = make(); f.reader.value = .success([f.val:PortfolioRawBalance(free:3,reserved:0,frozen:0)]); f.subject.start(); await settled(f); XCTAssertEqual(Set(f.prices.calls.last ?? []),Set([f.xor,f.val])) }
    func testPriceRequestsOmitUnheldNonNativeAssets() async { let f = make(); f.subject.start(); await settled(f); XCTAssertEqual(f.prices.calls.last,[f.xor]) }
    func testExactPriceIsAttachedToTheMatchingHolding() async throws { let f = make(); f.prices.info = PriceInfo(fiatData:[PIExactFiatData(id:f.xor,priceUsd:try PIQuantity("1.234567890123456789"))],marketCapInfo:[]); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.token.priceUSD,Decimal(string:"1.234567890123456789")) }
    func testUnpricedHoldingRemainsUnavailableRatherThanZeroPriced() async { let f = make(); f.subject.start(); await settled(f); XCTAssertNil(f.subject.snapshot.holdings.first?.token.priceUSD) }
    func testChangeCallbacksPublishOnlyOnTheMainThread() async { let f = make(); var updates = [PortfolioSnapshot](); f.subject.onChange = { XCTAssertTrue(Thread.isMainThread); updates.append($0) }; f.subject.start(); await settled(f); XCTAssertFalse(updates.isEmpty); XCTAssertEqual(updates.last,f.subject.snapshot) }
    func testAssetLookupUsesTheCurrentCatalog() { let f = make(); XCTAssertEqual(f.subject.asset(f.val)?.symbol,"VAL"); XCTAssertNil(f.subject.asset("missing")) }
    func testASlowWalletDoesNotHoldBackTheOthers() async { let f = make(); f.repository.accounts.append(LiveReadFixture.account("wallet-b",order:1)); f.reader.holdAddresses(["wallet-a"]); f.subject.start(); await wait{f.subject.snapshot.holdings.contains{$0.walletId == "wallet-b"}}; XCTAssertTrue(f.subject.snapshot.isLoading); XCTAssertFalse(f.subject.snapshot.holdings.contains{$0.walletId == "wallet-a"}); f.reader.release(); await settled(f); XCTAssertEqual(Set(f.subject.snapshot.holdings.map(\.walletId)),["wallet-a","wallet-b"]) }
    func testOnlyAFewWalletsAreReadAtOnceAndTheSelectedOneIsAmongTheFirst() async { let f = make(); f.repository.accounts = (0..<5).map{LiveReadFixture.account("other-\($0)",order:Int16($0))} + [LiveReadFixture.account("wallet-a",order:9)]; f.reader.held = true; f.subject.start(); await wait{f.reader.calls.count == 4}; try? await Task.sleep(nanoseconds:50_000_000); XCTAssertEqual(f.reader.calls.count,4); XCTAssertTrue(f.reader.calls.contains{$0.address == "wallet-a"}); f.reader.release(); await settled(f); XCTAssertEqual(f.reader.calls.count,6) }
    func testABalanceReadThatNeverAnswersFailsAtTheDeadline() async { let f = make(deadline:0.05); f.reader.held = true; f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.wallets.first?.freshness.unreachable,[.sora2]); XCTAssertNil(f.cache.reads["wallet-a"]?.lastRead); f.reader.release(); try? await Task.sleep(nanoseconds:30_000_000); XCTAssertNil(f.cache.reads["wallet-a"]?.lastRead,"A late answer is dropped") }
    func testAPriceReadThatNeverAnswersFailsAtTheDeadline() async { let f = make(deadline:0.05); f.prices.held = true; f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,10); XCTAssertNil(f.subject.snapshot.holdings.first?.token.priceUSD) }
    func testSavedBalancesShowAtOnceAndAreReadAgainAtLaunch() async { let defaults = UserDefaults(suiteName:UUID().uuidString)!; let store = PortfolioReadStore(defaults:defaults); let read = Date(timeIntervalSinceNow:-3600); store.save(reads:["wallet-a":PortfolioWalletReadState(sora2:[WalletAssetId.xor.rawValue:PortfolioRawBalance(free:5,reserved:0,frozen:0)],lastRead:read)],prices:PortfolioPriceSource()); let f = make(store:PortfolioReadStore(defaults:defaults)); f.reader.held = true; f.subject.start(); await wait{f.subject.snapshot.holdings.first?.amount == 5}; XCTAssertTrue(f.subject.snapshot.isLoading); XCTAssertEqual(f.subject.snapshot.wallets.first?.freshness,.saved(read)); await wait{f.reader.calls.count == 1}; f.reader.release(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,10); XCTAssertEqual(PortfolioReadStore(defaults:defaults).load()?.reads["wallet-a"]?.sora2?[f.xor]?.free,10,"The new read is saved") }
    func testARemovedWalletsSavedBalancesAreForgotten() async { let defaults = UserDefaults(suiteName:UUID().uuidString)!; let store = PortfolioReadStore(defaults:defaults); store.save(reads:["removed":PortfolioWalletReadState(sora2:[WalletAssetId.xor.rawValue:PortfolioRawBalance(free:5,reserved:0,frozen:0)],lastRead:Date())],prices:PortfolioPriceSource()); let f = make(store:PortfolioReadStore(defaults:defaults)); f.subject.start(); await settled(f); XCTAssertFalse(f.subject.snapshot.holdings.contains{$0.walletId == "removed"}); XCTAssertEqual(PortfolioReadStore(defaults:defaults).load()?.reads["removed"],nil); XCTAssertNotNil(PortfolioReadStore(defaults:defaults).load()?.reads["wallet-a"]) }
    func testSavedReadsRoundTripExactlyAndAreDueAReadAfterLoading() throws { let defaults = UserDefaults(suiteName:UUID().uuidString)!; let date = Date(timeIntervalSince1970:1_000), xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue; let exact = try XCTUnwrap(Decimal(string:"1.234567890123456789")); PortfolioReadStore(defaults:defaults).save(reads:["w":PortfolioWalletReadState(sora2:[xor:PortfolioRawBalance(free:exact,reserved:2,frozen:3),val:.zero],nexus:[.taira:7],lastRead:date,lastAttempt:date,failed:[.sora2])],prices:PortfolioPriceSource(usd:[xor:exact],change:[xor:-1.5],asOf:date,readAt:date)); let loaded = try XCTUnwrap(PortfolioReadStore(defaults:defaults).load()); let read = try XCTUnwrap(loaded.reads["w"]); XCTAssertEqual(read.sora2?[xor],PortfolioRawBalance(free:exact,reserved:2,frozen:3)); XCTAssertNil(read.sora2?[val],"Zero balances are not kept"); XCTAssertEqual(read.nexus,[.taira:7]); XCTAssertEqual(read.lastRead,date); XCTAssertNil(read.lastAttempt); XCTAssertEqual(read.failed,[]); XCTAssertEqual(loaded.prices,PortfolioPriceSource(usd:[xor:exact],change:[xor:-1.5],asOf:date,readAt:date)) }
    func testUnreadableSavedReadsStartEmpty() { let defaults = UserDefaults(suiteName:UUID().uuidString)!; defaults.set(Data("nonsense".utf8),forKey:PortfolioReadStore.key); XCTAssertNil(PortfolioReadStore(defaults:defaults).load()); XCTAssertTrue(PortfolioReadCache(store:PortfolioReadStore(defaults:defaults)).reads.isEmpty) }
    func testAnEmptyPriceAnswerKeepsSavedPricesAndSaysHowOld() async throws { let f = make(); let read = Date(timeIntervalSince1970:1_000); f.cache.prices = PortfolioPriceSource(usd:[f.xor:2],readAt:read); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.token.priceUSD,2); XCTAssertEqual(f.subject.snapshot.pricesAsOf,read) }
    func testFreshPricesClearTheAgeNote() async throws { let f = make(); f.cache.prices = PortfolioPriceSource(usd:[f.xor:2],asOf:Date(timeIntervalSince1970:1_000),readAt:Date(timeIntervalSince1970:1_000)); f.prices.info = PriceInfo(fiatData:[PIExactFiatData(id:f.xor,priceUsd:try PIQuantity("3"))],marketCapInfo:[]); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.token.priceUSD,3); XCTAssertNil(f.subject.snapshot.pricesAsOf); XCTAssertNotNil(f.cache.prices.readAt) }
    func testDisabledNexusDoesNotIssueAnyNexusReads() async { let f = make(); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.networks,[.sora2]); XCTAssertEqual(f.nexus.calls,0) }

    func testAnExplicitlyUnavailablePriceRemovesTheOldQuoteAndChange() async {
        let f = make()
        f.cache.prices = PortfolioPriceSource(usd: [f.xor: 2], change: [f.xor: 12], readAt: Date())
        f.prices.info = PriceInfo(fiatData: [PIExactFiatData(id: f.xor, priceUsd: nil)], marketCapInfo: [])
        f.subject.start()
        await settled(f)
        XCTAssertNil(f.subject.snapshot.holdings.first?.token.priceUSD)
        XCTAssertNil(f.subject.snapshot.holdings.first?.token.change24h)
        XCTAssertTrue(f.cache.prices.usd.isEmpty)
    }

    func testANewCatalogDropsAbsentQuotesInsteadOfMarkingThemFresh() async throws {
        let f = make()
        f.reader.value = .success([f.xor: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0),
                                  f.val: PortfolioRawBalance(free: 3, reserved: 0, frozen: 0)])
        f.cache.prices = PortfolioPriceSource(usd: [f.xor: 2, f.val: 9], change: [f.xor: 12, f.val: 5],
                                              readAt: Date(timeIntervalSinceNow: -3600))
        f.prices.info = PriceInfo(fiatData: [PIExactFiatData(id: f.xor, priceUsd: try PIQuantity("3"))],
                                 marketCapInfo: [])
        f.subject.start()
        await settled(f)
        let xor = try XCTUnwrap(f.subject.snapshot.holdings.first { $0.token.id == f.xor })
        let val = try XCTUnwrap(f.subject.snapshot.holdings.first { $0.token.id == f.val })
        XCTAssertEqual(xor.token.priceUSD, 3)
        XCTAssertNil(xor.token.change24h, "A current quote without change data must not reuse yesterday's change")
        XCTAssertNil(val.token.priceUSD)
        XCTAssertNil(val.token.change24h)
        XCTAssertEqual(PortfolioAggregator.summary(f.subject.snapshot, scope: .allWallets).total, 30)
    }

    func testAZeroRefreshReplacesSavedHoldingsAndSurvivesAnOfflineRefresh() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let f = make(cached: true, store: PortfolioReadStore(defaults: defaults))
        f.reader.value = .success([f.xor: .zero])
        f.subject.refreshAll()
        await settled(f)
        XCTAssertTrue(f.subject.snapshot.holdings.isEmpty)
        f.reader.value = .failure(LiveReadError.offline)
        f.subject.refreshAll()
        await wait { f.cache.reads["wallet-a"]?.failed == [.sora2] }
        XCTAssertTrue(f.subject.snapshot.holdings.isEmpty)
        XCTAssertEqual(PortfolioReadStore(defaults: defaults).load()?.reads["wallet-a"]?.sora2, [:])
    }
}
private enum LiveReadError: Error { case offline }
@MainActor
private final class LiveReadFixture {
    let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue
    let repository = LiveReadRepository(), reader = LiveReadBalances(), nexus = LiveReadNexus(), prices = LiveReadPrices(), assets = LiveReadAssets()
    let cache: PortfolioReadCache, deadline: TimeInterval
    lazy var subject = LivePortfolioDataSource(assetManager:assets,sora2Reader:reader,nexusReader:nexus,accountRepository:AnyDataProviderRepository(repository),cache:cache,priceService:prices,readDeadline:deadline)
    init(cached:Bool,store:PortfolioReadStore?,deadline:TimeInterval) { cache = PortfolioReadCache(store:store); self.deadline = deadline; repository.accounts = [Self.account("wallet-a")]; reader.value = .success([xor:PortfolioRawBalance(free:10,reserved:0,frozen:0)]); if cached { cache.wallets = [PortfolioWalletSource(id:"wallet-a",name:"First",order:0,isSelected:true,visibleAssetIds:nil,orderedAssetIds:nil,addresses:[:])]; cache.reads["wallet-a"] = PortfolioWalletReadState(sora2:[xor:PortfolioRawBalance(free:5,reserved:0,frozen:0)],lastRead:Date(),lastAttempt:Date()) } }
    nonisolated static func account(_ address:String,order:Int16 = 0)->AccountItem { AccountItem(address:address,cryptoType:.sr25519,networkType:Chain.sora.addressType(),username:address,publicKeyData:Data(repeating:3,count:32),settings:AccountSettings(visibleAssetIds:[],orderedAssetIds:[]),order:order,isSelected:false) }
}
private final class LiveReadRepository: DataProviderRepositoryProtocol {
    typealias Model = AccountItem
    var accounts = [AccountItem](), failure:Error?, writes = 0, fetches = 0
    func fetchAllOperation(with options:RepositoryFetchOptions)->BaseOperation<[AccountItem]> { fetches += 1; return ClosureOperation { if let failure = self.failure {throw failure}; return self.accounts } }
    func fetchOperation(by ids:@escaping()throws->[String],options:RepositoryFetchOptions)->BaseOperation<[AccountItem]>{ ClosureOperation{[]} }
    func fetchOperation(by id:@escaping()throws->String,options:RepositoryFetchOptions)->BaseOperation<AccountItem?>{ ClosureOperation{nil} }
    func fetchOperation(by request:RepositorySliceRequest,options:RepositoryFetchOptions)->BaseOperation<[AccountItem]>{ClosureOperation{[]}}
    func saveOperation(_ update:@escaping()throws->[AccountItem],_ delete:@escaping()throws->[String])->BaseOperation<Void>{writes += 1;return ClosureOperation{}}
    func saveBatchOperation(_ update:@escaping()throws->[AccountItem],_ delete:@escaping()throws->[String])->BaseOperation<Void>{writes += 1;return ClosureOperation{}}
    func replaceOperation(_ models:@escaping()throws->[AccountItem])->BaseOperation<Void>{writes += 1;return ClosureOperation{}}
    func fetchCountOperation()->BaseOperation<Int>{ClosureOperation{self.accounts.count}}
    func deleteAllOperation()->BaseOperation<Void>{writes += 1;return ClosureOperation{}}
}
private final class LiveReadBalances: PortfolioSora2BalanceReading {
    struct Call { let address:String; let assets:[(id:String,precision:Int16)] }
    // Wallets are read side by side, so calls can arrive on several threads at once.
    private let lock = NSLock()
    private var recorded = [Call](), heldAddresses = Set<String>(), pending = [CheckedContinuation<Void,Never>]()
    var value:Result<[String:PortfolioRawBalance],Error> = .success([:]), held = false
    var calls:[Call] { locked { recorded } }
    func holdAddresses(_ addresses:Set<String>){ locked { heldAddresses = addresses } }
    private func locked<T>(_ work:()->T)->T { lock.lock(); defer { lock.unlock() }; return work() }
    private func holds(_ address:String)->Bool { held || heldAddresses.contains(address) }
    func balances(address:String,assets:[(id:String,precision:Int16)]) async throws->[String:PortfolioRawBalance] {
        let result:Result<[String:PortfolioRawBalance],Error> = locked { recorded.append(Call(address:address,assets:assets)); return value }
        if locked({ holds(address) }) { await withCheckedContinuation { (continuation:CheckedContinuation<Void,Never>) in let waits:Bool = locked { guard holds(address) else { return false }; pending.append(continuation); return true }; if !waits { continuation.resume() } } }
        return try result.get()
    }
    func release(){ let waiting:[CheckedContinuation<Void,Never>] = locked { held = false; heldAddresses = []; defer { pending = [] }; return pending }; waiting.forEach { $0.resume() } }
}
private final class LiveReadNexus: PortfolioNexusBalanceReading { var calls = 0; func xorBalance(account:NetworkAccount) async throws->Decimal { calls += 1; XCTFail("No Nexus read expected"); throw LiveReadError.offline } }
private final class LiveReadPrices: PriceInfoServiceProtocol {
    private let lock = NSLock()
    private var pending = [CheckedContinuation<Void,Never>]()
    var calls = [[String]](), info = PriceInfo(fiatData:[],marketCapInfo:[]), held = false
    func getPriceInfo(for ids:[String]) async->PriceInfo { calls.append(ids); let answer = info; if held { await withCheckedContinuation { (continuation:CheckedContinuation<Void,Never>) in hold(continuation) } }; return answer }
    private func hold(_ continuation:CheckedContinuation<Void,Never>){ lock.lock(); pending.append(continuation); lock.unlock() }
    func release(){ lock.lock(); let waiting = pending; pending = []; lock.unlock(); waiting.forEach { $0.resume() } }
}
private final class LiveReadAssets: AssetManagerProtocol {
    static var networkAssets:[AssetInfo] = []
    var items = [AssetInfo(id:WalletAssetId.xor.rawValue,symbol:"XOR",chainId:"",precision:18,icon:nil,displayName:"SORA",visible:true),AssetInfo(id:WalletAssetId.val.rawValue,symbol:"VAL",chainId:"",precision:6,icon:nil,displayName:"Validator",visible:true)]
    func assetInfo(for id:String)->AssetInfo?{items.first{$0.assetId == id}}
    func getAssetList()->[AssetInfo]?{items};func updateAssetList(_ list:[AssetInfo]){items = list};func saveAssetList(_ list:[AssetInfo]){XCTFail("Reads must not alter the catalog")};func sortedAssets(_ list:[WalletAsset],onlyVisible:Bool)->[WalletAsset]{list};func visibleCount()->UInt{UInt(items.count)};func setup(for accountSettings:SelectedWalletSettings){}
}
