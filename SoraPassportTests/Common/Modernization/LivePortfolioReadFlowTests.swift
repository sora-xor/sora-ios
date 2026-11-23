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
    func testAPriceReadThatNeverAnswersFailsAtTheDeadline() async { let f = make(deadline:0.05); f.prices.held = true; f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,10); XCTAssertNil(f.subject.snapshot.holdings.first?.token.priceUSD); f.subject.refreshAll(); await wait{ f.prices.calls.count == 2 }; XCTAssertEqual(f.prices.calls.count,2,"the held price read ended at its deadline and freed the next one") }
    func testSavedBalancesShowAtOnceAndAreReadAgainAtLaunch() async { let defaults = UserDefaults(suiteName:UUID().uuidString)!; let store = PortfolioReadStore(defaults:defaults); let read = Date(timeIntervalSinceNow:-3600); store.save(reads:["wallet-a":PortfolioWalletReadState(sora2:[WalletAssetId.xor.rawValue:PortfolioRawBalance(free:5,reserved:0,frozen:0)],lastRead:read)],prices:PortfolioPriceSource()); let f = make(store:PortfolioReadStore(defaults:defaults)); f.reader.held = true; f.subject.start(); await wait{f.subject.snapshot.holdings.first?.amount == 5}; XCTAssertTrue(f.subject.snapshot.isLoading); XCTAssertEqual(f.subject.snapshot.wallets.first?.freshness,.saved(read)); await wait{f.reader.calls.count == 1}; f.reader.release(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,10); XCTAssertEqual(PortfolioReadStore(defaults:defaults).load()?.reads["wallet-a"]?.sora2?[f.xor]?.free,10,"The new read is saved") }
    func testARemovedWalletsSavedBalancesAreForgotten() async { let defaults = UserDefaults(suiteName:UUID().uuidString)!; let store = PortfolioReadStore(defaults:defaults); store.save(reads:["removed":PortfolioWalletReadState(sora2:[WalletAssetId.xor.rawValue:PortfolioRawBalance(free:5,reserved:0,frozen:0)],lastRead:Date())],prices:PortfolioPriceSource()); let f = make(store:PortfolioReadStore(defaults:defaults)); f.subject.start(); await settled(f); XCTAssertFalse(f.subject.snapshot.holdings.contains{$0.walletId == "removed"}); XCTAssertEqual(PortfolioReadStore(defaults:defaults).load()?.reads["removed"],nil); XCTAssertNotNil(PortfolioReadStore(defaults:defaults).load()?.reads["wallet-a"]) }
    func testSavedReadsRoundTripExactlyAndAreDueAReadAfterLoading() throws { let defaults = UserDefaults(suiteName:UUID().uuidString)!; let date = Date(timeIntervalSince1970:1_000), xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue; let exact = try XCTUnwrap(Decimal(string:"1.234567890123456789")); PortfolioReadStore(defaults:defaults).save(reads:["w":PortfolioWalletReadState(sora2:[xor:PortfolioRawBalance(free:exact,reserved:2,frozen:3),val:.zero],nexus:[.taira:7],lastRead:date,lastAttempt:date,failed:[.sora2])],prices:PortfolioPriceSource(usd:[xor:exact],change:[xor:-1.5],asOf:date,readAt:date)); let loaded = try XCTUnwrap(PortfolioReadStore(defaults:defaults).load()); let read = try XCTUnwrap(loaded.reads["w"]); XCTAssertEqual(read.sora2?[xor],PortfolioRawBalance(free:exact,reserved:2,frozen:3)); XCTAssertNil(read.sora2?[val],"Zero balances are not kept"); XCTAssertEqual(read.nexus,[.taira:7]); XCTAssertEqual(read.lastRead,date); XCTAssertNil(read.lastAttempt); XCTAssertEqual(read.failed,[]); XCTAssertEqual(loaded.prices,PortfolioPriceSource(usd:[xor:exact],change:[xor:-1.5],asOf:date,readAt:date)) }
    func testUnreadableSavedReadsStartEmpty() { let defaults = UserDefaults(suiteName:UUID().uuidString)!; defaults.set(Data("nonsense".utf8),forKey:PortfolioReadStore.key); XCTAssertNil(PortfolioReadStore(defaults:defaults).load()); XCTAssertTrue(PortfolioReadCache(store:PortfolioReadStore(defaults:defaults)).reads.isEmpty) }
    func testAnEmptyPriceAnswerKeepsSavedPricesAndSaysHowOld() async throws { let f = make(); let read = Date(timeIntervalSince1970:1_000); f.cache.prices = PortfolioPriceSource(usd:[f.xor:2],readAt:read); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.token.priceUSD,2); XCTAssertEqual(f.subject.snapshot.pricesAsOf,read) }
    func testFreshPricesClearTheAgeNote() async throws { let f = make(); f.cache.prices = PortfolioPriceSource(usd:[f.xor:2],asOf:Date(timeIntervalSince1970:1_000),readAt:Date(timeIntervalSince1970:1_000)); f.prices.info = PriceInfo(fiatData:[PIExactFiatData(id:f.xor,priceUsd:try PIQuantity("3"))],marketCapInfo:[]); f.subject.start(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.token.priceUSD,3); XCTAssertNil(f.subject.snapshot.pricesAsOf); XCTAssertNotNil(f.cache.prices.readAt) }
    func testLoadingEndsWithTheBalancesNotWithThePrices() async { let f = make(); f.prices.held = true; f.subject.start(); await wait{ !f.subject.snapshot.isLoading }; XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,10); XCTAssertEqual(f.prices.calls,[[f.xor]]); f.prices.release(); await settled(f) }
    func testPricesAreAskedForWhileTheBalancesAreStillBeingRead() async { let f = make(); f.reader.held = true; f.subject.start(); await wait{ !f.prices.calls.isEmpty && f.reader.calls.count == 1 }; XCTAssertTrue(f.subject.snapshot.isLoading); XCTAssertEqual(f.reader.calls.count,1); f.reader.release(); await settled(f); XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,10) }
    func testFailedReadsAreCountedAndASuccessResetsThem() async { let f = make(); f.reader.value = .failure(LiveReadError.offline); f.subject.refreshAll(); await settled(f); XCTAssertEqual(f.cache.reads["wallet-a"]?.failedReads,1); f.reader.value = .success([f.xor:PortfolioRawBalance(free:10,reserved:0,frozen:0)]); f.subject.refreshAll(); await wait{ f.cache.reads["wallet-a"]?.failedReads == 0 }; XCTAssertEqual(f.subject.snapshot.holdings.first?.amount,10) }
    func testARetryIsCountedFromTheFailureNotFromTheAttempt() async { let f = make(cached:true); f.cache.reads["wallet-a"]?.failedReads = 1; f.cache.reads["wallet-a"]?.lastAttempt = Date(timeIntervalSinceNow:-30); f.cache.reads["wallet-a"]?.lastFailure = Date(timeIntervalSinceNow:-1); f.subject.start(); await settled(f); XCTAssertTrue(f.reader.calls.isEmpty) }
    func testAFailedReadIsTriedAgainLongBeforeTheMinute() async { let f = make(cached:true); f.cache.reads["wallet-a"]?.failedReads = 1; f.cache.reads["wallet-a"]?.lastAttempt = Date(timeIntervalSinceNow:-6); f.subject.start(); await settled(f); XCTAssertEqual(f.reader.calls.count,1) }
    func testABalanceRefreshIsNotHeldBackByAPendingPriceRead() async { let f = make(); f.prices.held = true; f.subject.start(); await wait{ !f.subject.snapshot.isLoading && f.reader.calls.count == 1 }; f.subject.refreshAll(); await wait{ f.reader.calls.count == 2 }; XCTAssertEqual(f.prices.calls.count,1,"the price read is still the first one"); f.prices.release(); await settled(f) }
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

    func testANewlyImportedWalletNeverFlashesThePreviousWalletsCachedBalance() {
        let f = make(cached: true)
        SelectedWalletSettings.shared.commitInternalValue(LiveReadFixture.account("new-wallet"))
        XCTAssertTrue(f.subject.snapshot.wallets.isEmpty)
        XCTAssertTrue(f.subject.snapshot.holdings.isEmpty)
        XCTAssertTrue(f.subject.snapshot.isLoading)
    }

    func testTheCachedFirstFrameUsesTheCurrentWalletSelection() {
        let f = make(cached: true)
        f.cache.wallets.append(PortfolioWalletSource(id: "wallet-b", name: "Second", order: 1,
                                                     isSelected: false, visibleAssetIds: nil,
                                                     orderedAssetIds: nil, addresses: [:]))
        SelectedWalletSettings.shared.commitInternalValue(LiveReadFixture.account("wallet-b"))
        XCTAssertEqual(f.subject.snapshot.wallets.filter(\.isSelected).map(\.id), ["wallet-b"])
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

    /// A blacklist that arrives after the portfolio is on screen hides the holding at once,
    /// without waiting for the next balance read.
    func testABlacklistThatArrivesLaterHidesTheHoldingAtOnce() async {
        let f = make(cached: true)
        f.cache.reads["wallet-a"] = PortfolioWalletReadState(sora2: [f.xor: PortfolioRawBalance(free: 5, reserved: 0, frozen: 0),
                                                                     f.val: PortfolioRawBalance(free: 4, reserved: 0, frozen: 0)],
                                                             lastRead: Date(), lastAttempt: Date())
        let blacklist = FixedAssetBlacklist(AssetBlacklist(assetIds: [], source: .remote))
        f.subject.assetBlacklist = blacklist
        var updates = 0
        f.subject.onChange = { _ in updates += 1 }
        XCTAssertEqual(f.subject.snapshot.holdings.first { $0.token.id == f.val }?.isBlacklisted, false)
        blacklist.list = AssetBlacklist(assetIds: [f.val], source: .remote)
        NotificationCenter.default.post(name: AssetBlacklistStore.didChange, object: nil)
        await wait { f.subject.snapshot.holdings.first { $0.token.id == f.val }?.isBlacklisted == true }
        XCTAssertEqual(f.subject.snapshot.holdings.first { $0.token.id == f.val }?.isHidden, true)
        XCTAssertGreaterThan(updates, 0)
        XCTAssertTrue(f.reader.calls.isEmpty, "no balance is read for it")
    }

    // MARK: An account list that cannot be read

    func testAFailedAccountListReadWithNothingKnownStaysLoadingAndNeverLooksEmpty() async {
        let f = make()
        f.repository.failure = LiveReadError.offline
        var lookedEmpty = false
        f.subject.onChange = { snapshot in
            if !snapshot.isLoading, snapshot.wallets.isEmpty { lookedEmpty = true }
        }
        f.subject.start()
        await wait { f.subject.finishedPasses == 1 }
        XCTAssertEqual(f.repository.thrown, 1)
        XCTAssertTrue(f.subject.snapshot.isLoading, "no wallet list is not an empty wallet")
        XCTAssertTrue(f.subject.snapshot.wallets.isEmpty)
        // Account storage answers at the next read.
        f.repository.failure = nil
        f.subject.refreshAll()
        await settled(f)
        XCTAssertEqual(f.repository.thrown, 1)
        XCTAssertFalse(lookedEmpty)
        XCTAssertEqual(f.subject.snapshot.holdings.first?.amount, 10)
    }

    // MARK: A token list that grows

    func testATokenListedAfterAPassIsReadAtTheNextPassNotAMinuteLater() async {
        let f = make()
        let full = f.assets.items
        f.assets.items = full.filter { $0.assetId == f.xor }
        f.subject.start()
        await settled(f)
        XCTAssertEqual(f.reader.calls.map { $0.assets.map(\.id) }, [[f.xor]])
        // The same list: the next pass reads nothing, the wallet was read a moment ago.
        f.subject.stop()
        f.subject.start()
        await wait { f.subject.finishedPasses == 2 }
        XCTAssertEqual(f.reader.calls.count, 1)
        // VAL is listed: no wallet has been asked about it.
        f.assets.items = full
        f.reader.value = .success([f.xor: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0),
                                   f.val: PortfolioRawBalance(free: 3, reserved: 0, frozen: 0)])
        f.subject.stop()
        f.subject.start()
        await wait { f.reader.calls.count == 2 }
        XCTAssertEqual(f.reader.calls.last?.assets.map(\.id), [f.xor, f.val])
        await wait { f.subject.snapshot.holdings.first { $0.token.id == f.val }?.amount == 3 }
        // A list that only lost a token leaves nothing unread.
        f.assets.items = full.filter { $0.assetId == f.xor }
        f.subject.stop()
        f.subject.start()
        await wait { f.subject.finishedPasses == 4 }
        XCTAssertEqual(f.reader.calls.count, 2)
    }

    func testAnotherTabWaitsForAReadThatAlreadyAsksAboutTheNewToken() async {
        let f = make()
        let full = f.assets.items
        f.assets.items = full.filter { $0.assetId == f.xor }
        f.subject.start()
        await settled(f)
        // VAL is listed, and the wallet's read that asks about it is under way.
        f.assets.items = full
        f.reader.value = .success([f.xor: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0),
                                   f.val: PortfolioRawBalance(free: 3, reserved: 0, frozen: 0)])
        f.reader.held = true
        f.subject.stop()
        f.subject.start()
        await wait { f.reader.calls.count == 2 }
        // A Wallet tab built meanwhile does not start the same read over it.
        let reader = LiveReadBalances()
        let newer = LivePortfolioDataSource(assetManager: LiveReadAssets(), sora2Reader: reader, nexusReader: f.nexus,
                                            accountRepository: AnyDataProviderRepository(f.repository), cache: f.cache,
                                            priceService: LiveReadPrices(), readDeadline: 15)
        defer { newer.stop() }
        newer.start()
        await wait { newer.finishedPasses == 1 }
        XCTAssertTrue(reader.calls.isEmpty)
        f.reader.release()
        await wait { f.cache.reads["wallet-a"]?.sora2?[f.val]?.free == 3 }
    }

    // MARK: Two Wallet tabs (a tab rebuilt while the first one reads)

    /// Five wallets on a cold start; this tab reads four at once and queues the fifth, which a
    /// newer tab begins reading meanwhile. Each tab still reads it when its turn comes (as on
    /// master): a tab never ends its first pass on a read it does not wait for.
    func testTheFirstPassDoesNotEndBeforeAQueuedWalletAnotherTabBeganIsRead() async {
        let f = make()
        f.repository.accounts = (0..<5).map { LiveReadFixture.account("w\($0)", order: Int16($0)) }
        SelectedWalletSettings.shared.commitInternalValue(LiveReadFixture.account("w0"))
        f.reader.holdAddresses(["w0", "w1", "w2", "w3"])
        var endedWithAnUnreadWallet = false
        f.subject.onChange = { snapshot in
            if !snapshot.isLoading, snapshot.wallets.contains(where: { $0.freshness.updatedAt == nil }) {
                endedWithAnUnreadWallet = true
            }
        }
        f.subject.start()
        await wait { f.reader.calls.count == 4 }
        // The newer tab begins the fifth wallet's read, and its node is slow.
        let reader = LiveReadBalances()
        reader.value = .success([f.xor: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0)])
        reader.held = true
        let newer = LivePortfolioDataSource(assetManager: LiveReadAssets(), sora2Reader: reader, nexusReader: f.nexus,
                                            accountRepository: AnyDataProviderRepository(f.repository), cache: f.cache,
                                            priceService: LiveReadPrices(), readDeadline: 15)
        defer { newer.stop(); reader.release() }
        newer.start()
        await wait { reader.calls.map(\.address) == ["w4"] }
        f.reader.release()
        await wait { f.subject.finishedPasses == 1 && !f.subject.isReading }
        XCTAssertTrue(f.reader.calls.contains { $0.address == "w4" }, "the queued wallet is read here too")
        XCTAssertFalse(endedWithAnUnreadWallet, "loading never ends with a wallet whose read is still pending")
        XCTAssertFalse(f.subject.snapshot.isLoading)
    }

    /// The queued wallet's Taira address is known to this tab only (the newer tab loaded the
    /// account list before it was added): this tab still reads it.
    func testAQueuedWalletIsReadOnEveryNetworkThisTabKnowsEvenWhenAnotherTabBeganItsRead() async {
        SettingsManager.shared.nexusEnabled = true
        SettingsManager.shared.isTairaEnabled = true
        let f = make()
        f.repository.accounts = (0..<5).map { LiveReadFixture.account("w\($0)", order: Int16($0)) }
        SelectedWalletSettings.shared.commitInternalValue(LiveReadFixture.account("w0"))
        let taira = NetworkAccount(walletId: "w4", networkId: .taira, derivationVersion: 1,
                                   publicKey: Data(repeating: 3, count: 32), address: "taira-w4")
        let nexus = LiveReadNexusRecorder()
        f.reader.holdAddresses(["w0", "w1", "w2", "w3"])
        let first = LivePortfolioDataSource(assetManager: f.assets, sora2Reader: f.reader, nexusReader: nexus,
                                            accountRepository: AnyDataProviderRepository(f.repository), cache: f.cache,
                                            priceService: LiveReadPrices(), readDeadline: 15,
                                            networkAccounts: { [taira] })
        defer { first.stop() }
        first.start()
        await wait { f.reader.calls.count == 4 }
        let reader = LiveReadBalances()
        reader.value = .success([f.xor: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0)])
        let newer = LivePortfolioDataSource(assetManager: LiveReadAssets(), sora2Reader: reader, nexusReader: nexus,
                                            accountRepository: AnyDataProviderRepository(f.repository), cache: f.cache,
                                            priceService: LiveReadPrices(), readDeadline: 15,
                                            networkAccounts: { [] })
        defer { newer.stop() }
        newer.start()
        await wait { newer.finishedPasses == 1 }
        XCTAssertEqual(reader.calls.map(\.address), ["w4"])
        XCTAssertTrue(nexus.addresses.isEmpty)
        f.reader.release()
        await wait { first.finishedPasses == 1 && !first.isReading }
        XCTAssertEqual(nexus.addresses, ["taira-w4"])
        XCTAssertEqual(f.cache.reads["w4"]?.nexus[.taira], 7)
    }

    func testATokenListThatGrowsWhileTheTabIsAwayIsReadAtItsNextAppearance() async {
        let f = make()
        let full = f.assets.items
        f.assets.items = full.filter { $0.assetId == f.xor }
        f.reader.held = true
        f.subject.start()
        await wait { f.reader.calls.count == 1 }
        // The tab is left while the first read is under way, shown again for a moment (which
        // queues a pass) and left again; VAL is listed meanwhile.
        f.subject.stop()
        f.subject.start()
        f.subject.stop()
        f.assets.items = full
        f.reader.release()
        await wait { f.subject.finishedPasses == 1 && !f.subject.isReading }
        XCTAssertEqual(f.reader.calls.count, 1, "nothing is read while the tab is away")
        XCTAssertEqual(f.subject.finishedPasses, 1)
        XCTAssertTrue(f.subject.snapshot.isLoading, "VAL is unread: the first pass is not over")
        f.subject.start()
        await wait { f.reader.calls.count == 2 }
        XCTAssertEqual(f.reader.calls.last?.assets.map(\.id), [f.xor, f.val])
    }

    func testAnAnswerDroppedForANewerReadLeavesTheNewerReadsTokens() async {
        let f = make()
        let full = f.assets.items
        f.assets.items = full.filter { $0.assetId == f.xor }
        f.reader.held = true
        f.subject.start()
        await wait { f.reader.calls.count == 1 }
        // A newer Wallet tab reads the wallet with the full list while that read is under way.
        let reader = LiveReadBalances()
        reader.value = .success([f.xor: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0),
                                 f.val: PortfolioRawBalance(free: 3, reserved: 0, frozen: 0)])
        let newer = LivePortfolioDataSource(assetManager: LiveReadAssets(), sora2Reader: reader, nexusReader: f.nexus,
                                            accountRepository: AnyDataProviderRepository(f.repository), cache: f.cache,
                                            priceService: LiveReadPrices(), readDeadline: 15)
        defer { newer.stop() }
        newer.refreshAll()
        await wait { newer.finishedPasses == 1 }
        // The first tab's answer arrives late, for a shorter list: it is dropped, and so is its list.
        f.reader.release()
        await wait { f.subject.finishedPasses == 1 }
        XCTAssertEqual(f.cache.reads["wallet-a"]?.sora2?[f.val]?.free, 3)
        XCTAssertEqual(f.cache.reads["wallet-a"]?.sora2Coverage?.count, 2)
        // The newer tab finds the wallet read for every token a moment ago: nothing is read again.
        newer.start()
        await wait { newer.finishedPasses == 2 }
        XCTAssertEqual(reader.calls.count, 1)
    }

    func testATokenListThatGrowsDuringTheFirstPassKeepsLoadingAndIsReadAtOnce() async {
        let f = make()
        let full = f.assets.items
        f.assets.items = full.filter { $0.assetId == f.xor }
        f.reader.held = true
        f.subject.start()
        await wait { f.reader.calls.count == 1 }
        XCTAssertEqual(f.reader.calls.first?.assets.map(\.id), [f.xor])
        // The full list arrives while the node is still answering the first read.
        f.assets.items = full
        var finishedWithoutVal = false
        f.subject.onChange = { snapshot in
            if !snapshot.isLoading, !snapshot.holdings.contains(where: { $0.token.id == f.val }) { finishedWithoutVal = true }
        }
        f.reader.value = .success([f.xor: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0),
                                   f.val: PortfolioRawBalance(free: 3, reserved: 0, frozen: 0)])
        f.reader.release()
        await wait { f.reader.calls.count == 2 }
        XCTAssertEqual(f.reader.calls.last?.assets.map(\.id), [f.xor, f.val], "the list that grew is read at once, not a minute later")
        await settled(f)
        XCTAssertEqual(f.subject.snapshot.holdings.first { $0.token.id == f.val }?.amount, 3)
        XCTAssertFalse(finishedWithoutVal, "the first pass is not over while a listed token is unread")
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
    private let lock = NSLock()
    private var thrownCount = 0
    /// How many account list reads have failed, counted when the operation throws.
    var thrown:Int { lock.lock(); defer { lock.unlock() }; return thrownCount }
    private func countThrown() { lock.lock(); thrownCount += 1; lock.unlock() }
    // The answer is fixed when the read is asked for: a test that changes it afterwards changes the next read.
    func fetchAllOperation(with options:RepositoryFetchOptions)->BaseOperation<[AccountItem]> { fetches += 1; let failure = self.failure, accounts = self.accounts; return ClosureOperation { [weak self] in if let failure { self?.countThrown(); throw failure }; return accounts } }
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
private final class LiveReadNexusRecorder: PortfolioNexusBalanceReading {
    private let lock = NSLock()
    private var recorded = [String]()
    var addresses: [String] { lock.lock(); defer { lock.unlock() }; return recorded }
    private func record(_ address: String) { lock.lock(); recorded.append(address); lock.unlock() }
    func xorBalance(account: NetworkAccount) async throws -> Decimal { record(account.address); return 7 }
}
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
