// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import RobinHood
import sorawallet

final class HistoryPage {
    let transactions: [Transaction]
    let errorMessage: String?
    let endReached: Bool
    /// The indexer listed only operations this account signed, so transfers
    /// that others sent to it may be missing. Balances are not affected.
    let mayOmitIncomingTransfers: Bool
    /// `nil` when the page was read from the indexer just now. Otherwise
    /// the indexer could not be read and this is the page as it was saved
    /// at this time.
    let cachedAt: Date?

    init(
        transactions: [Transaction],
        endReached: Bool,
        errorMessage: String? = nil,
        mayOmitIncomingTransfers: Bool = false,
        cachedAt: Date? = nil
    ) {
        self.transactions = transactions
        self.endReached = endReached
        self.errorMessage = errorMessage
        self.mayOmitIncomingTransfers = mayOmitIncomingTransfers
        self.cachedAt = cachedAt
    }
}

protocol HistoryServiceProtocol {
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Swift.Error>) -> Void)
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void)
    func getTransaction(by txHash: String) -> Transaction?
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction]
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage
}

final class HistoryService {

    /// One page of the indexer's history, as far as the screens need it.
    struct RemotePage {
        let items: [TxHistoryItem]
        let endReached: Bool
        let errorMessage: String?
        let mayOmitIncomingTransfers: Bool
        let cachedAt: Date?

        init(
            items: [TxHistoryItem],
            endReached: Bool,
            errorMessage: String? = nil,
            mayOmitIncomingTransfers: Bool = false,
            cachedAt: Date? = nil
        ) {
            self.items = items
            self.endReached = endReached
            self.errorMessage = errorMessage
            self.mayOmitIncomingTransfers = mayOmitIncomingTransfers
            self.cachedAt = cachedAt
        }
    }

    typealias HistoryFilter = (TxHistoryItem) -> KotlinBoolean
    /// Reads one page of this account's history from the indexer.
    typealias RemoteRead = (
        _ address: String,
        _ count: Int,
        _ page: Int,
        _ filter: HistoryFilter?
    ) async throws -> RemotePage

    private var address: String
    private let operationManager: OperationManager
    private let historyMapper: HistoryTransactionMapperProtocol
    private let transactionsLock = NSLock()
    private var transactions: [Transaction] = []
    private var localStorage: LocalTransactionStorageProtocol
    private let readRemote: RemoteRead?
    private let readJournal: () -> [Sora2PendingSubmission]
    private let now: () -> Date
    
    /// - Parameters:
    ///   - readRemote: The indexer read; nil for the app's own.
    ///   - readJournal: The app's journal of sent transactions. It is read
    ///     where a page is put together, never on the main thread.
    init(operationManager: OperationManager,
         address: String,
         assets: [AssetInfo],
         localStorage: LocalTransactionStorageProtocol = LocalTransactionStorage.shared,
         readRemote: RemoteRead? = nil,
         readJournal: @escaping () -> [Sora2PendingSubmission] = HistoryService.sentTransactionJournal,
         now: @escaping () -> Date = Date.init) {
        self.operationManager = operationManager
        self.address = address
        self.historyMapper = HistoryTransactionMapper(myAddress: address, assets: assets)
        self.localStorage = localStorage
        self.readRemote = readRemote
        self.readJournal = readJournal
        self.now = now
    }

    /// The journal of transactions this device signed and handed to the
    /// network, with what the reconciler found out about each. Empty when
    /// it cannot be read: the history then shows what the indexer has.
    static func sentTransactionJournal() -> [Sora2PendingSubmission] {
        (try? Sora2PendingSubmissionStore().all()) ?? []
    }
}

extension HistoryService: HistoryServiceProtocol {
    @available(*, renamed: "getHistory(count:assetId:)")
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Swift.Error>) -> Void) {
        Task {
            do {
                let result = try await getHistory(count: count, assetId: assetId)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction] {
        let remote = try await remotePage(count: count, page: 1, assetId: assetId)
        let transactionsItems = try merged(remote, page: 1, assetId: assetId)
        remember(transactionsItems)
        return transactionsItems
    }
    
    @available(*, renamed: "getPageHistory(count:page:assetId:)")
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void) {
        Task {
            do {
                let result = try await getPageHistory(count: count, page: page, assetId: assetId)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage {
        let remote = try await remotePage(count: count, page: page, assetId: assetId)
        let transactionsItems = try merged(remote, page: page, assetId: assetId)
        remember(transactionsItems)
        return HistoryPage(
            transactions: transactionsItems,
            endReached: remote.errorMessage != nil ? true : remote.endReached,
            errorMessage: remote.errorMessage,
            mayOmitIncomingTransfers: remote.mayOmitIncomingTransfers,
            cachedAt: remote.cachedAt
        )
    }
    
    func getTransaction(by txHash: String) -> Transaction? {
        transactionsLock.lock()
        defer { transactionsLock.unlock() }
        return transactions.first { $0.base.txHash == txHash }
    }
}

private extension HistoryService {
    /// Seconds since 1970 of a row. Indexer rows carry whole seconds, rows
    /// of this run a fraction as well.
    static func seconds(_ transaction: Transaction) -> TimeInterval {
        TimeInterval(transaction.base.timestamp) ?? 0
    }

    /// The rows of one page, newest first: the indexer's rows, the
    /// transactions sent in this run that it does not list yet, and (on the
    /// first page) what the app's own journal knows about sent
    /// transactions.
    ///
    /// The journal is what makes a sent transaction keep a truthful status:
    /// a row of this run takes its final status from it, and a transaction
    /// the indexer does not list (not included at all, still on its way
    /// after a restart, or not indexed yet) gets a row of its own.
    func merged(_ remote: RemotePage, page: Int, assetId: String?) throws -> [Transaction] {
        let remoteTransactions: [Transaction] = try historyMapper.map(items: remote.items).compactMap { $0 }
        guard page == 1 else {
            return remoteTransactions.sorted { Self.seconds($0) > Self.seconds($1) }
        }
        let listedHashes = Set(remoteTransactions.map { $0.base.txHash })
        let localTransactions = (localStorage.transactions[address] ?? [])
            .filter { !listedHashes.contains($0.base.txHash) }
        let overlay = SentTransactionJournalOverlay.apply(
            address: address,
            journal: readJournal(),
            local: localTransactions,
            listedHashes: listedHashes,
            // The journal does not know which asset a transaction moved,
            // so a list for one asset shows no journal rows.
            listsJournalRows: assetId == nil,
            oldestListedTimestamp: remote.items.compactMap { TimeInterval($0.timestamp) }.min(),
            endReached: remote.endReached,
            now: now()
        )
        return (overlay.local + overlay.journalRows + remoteTransactions)
            .sorted { Self.seconds($0) > Self.seconds($1) }
    }

    /// Keeps the rows for `getTransaction(by:)`. A row that changed (a
    /// pending one that got its result) replaces the one kept before.
    func remember(_ items: [Transaction]) {
        transactionsLock.lock()
        defer { transactionsLock.unlock() }
        for transaction in items {
            if let index = transactions.firstIndex(where: { $0.base.txHash == transaction.base.txHash }) {
                transactions[index] = transaction
            } else {
                transactions.append(transaction)
            }
        }
    }

    func remotePage(count: Int, page: Int, assetId: String?) async throws -> RemotePage {
        let filter = Self.historyFilter(assetId: assetId)
        if let readRemote {
            return try await readRemote(address, count, page, filter)
        }
        let queryOperation = SubqueryHistoryOperation<TxHistoryResult<TxHistoryItem>>(address: address,
                                                                                      count: count,
                                                                                      page: page,
                                                                                      filter: filter)
        return try await withCheckedThrowingContinuation { continuation in
            queryOperation.completionBlock = {
                do {
                    let response = try queryOperation.extractNoCancellableResultData()
                    continuation.resume(returning: RemotePage(
                        items: response.items as? [TxHistoryItem] ?? [],
                        endReached: response.endReached,
                        errorMessage: response.errorMessage,
                        mayOmitIncomingTransfers:
                            queryOperation.historyCoverage == .signedByAccount,
                        cachedAt: queryOperation.cachedAt
                    ))
                } catch let error {
                    continuation.resume(throwing: error)
                }
            }
            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }

    /// The indexer rows that belong to one asset; nil for all rows.
    static func historyFilter(assetId: String?) -> HistoryFilter? {
        guard let assetId else { return nil }
        return { item in
            let callPath = KmmCallCodingPath(moduleName: item.module, callName: item.method)
            
            if callPath.isTransfer {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId)
            }
            
            if callPath == KmmCallCodingPath.bondReferralBalance ||
                callPath == KmmCallCodingPath.unbondReferralBalance ||
                callPath == KmmCallCodingPath.setReferral {
                return KotlinBoolean(value:assetId == WalletAssetId.xor.rawValue)
            }
            
            if callPath.isSwap {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "targetAssetId" }?.paramValue == assetId)
            }
            
            if callPath.isDepositLiquidity || callPath.isWithdrawLiquidity {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "targetAssetId" }?.paramValue == assetId)
            }
            
            if callPath == KmmCallCodingPath.batchUtility || callPath == KmmCallCodingPath.batchAllUtility {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "input_asset_a" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "input_asset_b" }?.paramValue == assetId)
            }
            
            if callPath.isClaimReward {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId)
            }
            
            if callPath.isDepositFarmLiquidity || callPath.isWithdrawFarmLiquidity {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "rewardAssetId" }?.paramValue == assetId)
            }
            
            return KotlinBoolean(value: false)
        }
    }
}

/// Brings what the app's journal of sent transactions knows into the
/// history the screens show.
///
/// The journal (`Sora2PendingSubmissionStore`) is written before a signed
/// transaction leaves the device, and the reconciler writes into it what
/// became of the transaction: succeeded or failed in a finalized block, or
/// not included before its validity ended. The indexer lists only what is
/// on the chain, and the rows of the current run live in memory, so without
/// the journal a transaction that was never included stayed "pending" until
/// the app was closed and then vanished without a word.
enum SentTransactionJournalOverlay {
    struct Result {
        /// The rows of this run, with the final status of each whose result
        /// is known.
        var local: [Transaction]
        /// Rows for sent transactions that neither the indexer nor this
        /// run lists.
        var journalRows: [Transaction]
    }

    static func outcome(of entry: Sora2PendingSubmission) -> SubmittedTransaction.Outcome {
        switch entry.terminalResolution?.kind {
        case .finalizedSuccess: return .succeeded
        case .finalizedFailure: return .failed
        case .expiredNotIncluded: return .notIncluded
        case .none: return .pending
        }
    }

    /// - Parameters:
    ///   - listedHashes: The transactions the indexer lists on this page;
    ///     its row is the record of each and the journal adds nothing.
    ///   - listsJournalRows: Whether transactions known only from the
    ///     journal get a row.
    ///   - oldestListedTimestamp: The time of the oldest indexer row on the
    ///     page. A journal entry older than that belongs further down the
    ///     list, where the indexer's own row for it (if it has one) is
    ///     shown; it gets no row here, so nothing is listed twice.
    ///   - endReached: The indexer has no older rows than this page.
    static func apply(
        address: String,
        journal: [Sora2PendingSubmission],
        local: [Transaction],
        listedHashes: Set<String>,
        listsJournalRows: Bool,
        oldestListedTimestamp: TimeInterval?,
        endReached: Bool,
        now: Date
    ) -> Result {
        var result = Result(local: local, journalRows: [])
        guard !journal.isEmpty, !address.isEmpty else {
            return result
        }
        // The same reading of the journal as everywhere else: entries of
        // this account, valid, not listed by the indexer; an entry without
        // a result counts as pending for a limited time only.
        let projected = TransactionHistoryMergeManager.pendingJournalOverlay(
            address: address,
            submissions: journal,
            visibleLocalItems: [],
            remoteHashes: Set(listedHashes.compactMap {
                Sora2PendingSubmissionStore.normalizedHash($0)
                    .flatMap { try? Data(hexStringSSF: $0) }
            }),
            now: now
        )
        var entries: [String: Sora2PendingSubmission] = [:]
        for entry in journal where entry.account == address {
            entries[entry.extrinsicHash] = entry
        }
        for item in projected {
            guard
                let hash = Sora2PendingSubmissionStore.normalizedHash(item.txHash),
                let entry = entries[hash]
            else {
                continue
            }
            let outcome = outcome(of: entry)
            if let index = result.local.firstIndex(where: {
                Sora2PendingSubmissionStore.normalizedHash($0.base.txHash) == hash
            }) {
                // The row of this run knows what was sent; the journal
                // knows what became of it.
                if outcome != .pending {
                    result.local[index].base.status = outcome.status
                }
                continue
            }
            // A row is for a transaction that was handed to the network
            // (or may have been) and whose fate the reconciler can find
            // out. An entry a feature owns (a legacy migration) is shown by
            // that feature; one that only reserved its place before
            // transport was never sent.
            guard
                listsJournalRows,
                entry.isGeneric,
                entry.recoveryContext != nil,
                entry.state != .stagedBeforeTransport
            else {
                continue
            }
            let timestamp = TimeInterval(item.timestamp)
            guard endReached || oldestListedTimestamp.map({ timestamp >= $0 }) ?? true else {
                continue
            }
            let blockHash = entry.terminalResolution?.blockHash ?? entry.finalizedInclusion?.blockHash
            result.journalRows.append(
                SubmittedTransaction(
                    base: TransactionBase(
                        txHash: item.txHash,
                        blockHash: blockHash.map { "0x\($0)" } ?? "",
                        fee: Amount(value: 0),
                        status: outcome.status,
                        timestamp: "\(item.timestamp)"
                    ),
                    outcome: outcome
                )
            )
        }
        return result
    }

    /// What the journal says became of one transaction of one account, or
    /// nil when it has no final result for it. Reads the journal file: call
    /// it off the main thread.
    static func finalOutcome(
        transactionHash: String,
        address: String,
        journal: [Sora2PendingSubmission]
    ) -> SubmittedTransaction.Outcome? {
        guard
            let hash = Sora2PendingSubmissionStore.normalizedHash(transactionHash),
            let entry = journal.first(where: { $0.account == address && $0.extrinsicHash == hash }),
            entry.terminalResolution != nil
        else {
            return nil
        }
        return outcome(of: entry)
    }
}
