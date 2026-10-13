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

import IrohaCrypto

struct TransactionHistoryMergeResult {
    let historyItems: [AssetTransactionData]
    let identifiersToRemove: [String]
}

enum TransactionHistoryMergeItem {
    case local(item: TransactionHistoryItem)
    case remote(remote: WalletRemoteHistoryItemProtocol)

    func compareWithItem(_ item: TransactionHistoryMergeItem) -> Bool {
        switch (self, item) {
        case let (.local(localItem1), .local(localItem2)):
            if localItem1.status == .pending, localItem2.status != .pending {
                return true
            } else {
                return compareBlockNumberIfExists(
                    number1: localItem1.blockNumber,
                    number2: localItem2.blockNumber,
                    timestamp1: localItem1.timestamp,
                    timestamp2: localItem2.timestamp
                )
            }

        case let (.local(localItem), .remote(remoteItem)):
            if localItem.status == .pending {
                return true
            } else {
                return compareBlockNumberIfExists(
                    number1: localItem.blockNumber,
                    number2: remoteItem.itemBlockNumber,
                    timestamp1: localItem.timestamp,
                    timestamp2: remoteItem.itemTimestamp
                )
            }
        case let (.remote(remoteItem), .local(localItem)):
            if localItem.status == .pending {
                return false
            } else {
                return compareBlockNumberIfExists(
                    number1: remoteItem.itemBlockNumber,
                    number2: localItem.blockNumber,
                    timestamp1: remoteItem.itemTimestamp,
                    timestamp2: localItem.timestamp
                )
            }
        case let (.remote(remoteItem1), .remote(remoteItem2)):
            return compareBlockNumberIfExists(
                number1: remoteItem1.itemBlockNumber,
                number2: remoteItem2.itemBlockNumber,
                timestamp1: remoteItem1.itemTimestamp,
                timestamp2: remoteItem2.itemTimestamp
            )
        }
    }

    func buildTransactionData(
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        switch self {
        case let .local(item):
            return AssetTransactionData.createTransaction(
                from: item,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        case let .remote(item):
            return item.createTransactionForAddress(
                address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }
    }

    private func compareBlockNumberIfExists(
        number1: UInt64?,
        number2: UInt64?,
        timestamp1: Int64,
        timestamp2: Int64
    ) -> Bool {
        if let number1 = number1, let number2 = number2 {
            return number1 != number2 ? number1 > number2 : timestamp1 > timestamp2
        }

        return timestamp1 > timestamp2
    }
}

final class TransactionHistoryMergeManager {
    let address: String
    let networkType: SNAddressType
    let asset: WalletAsset
    let addressFactory: SS58AddressFactoryProtocol

    init(
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) {
        self.address = address
        self.networkType = networkType
        self.asset = asset
        self.addressFactory = addressFactory
    }

    func merge(
        remoteItems: [WalletRemoteHistoryItemProtocol],
        localItems: [TransactionHistoryItem],
        pendingSubmissions: [Sora2PendingSubmission] = []
    ) -> TransactionHistoryMergeResult {
        let remoteHashes: [Data] = remoteItems.compactMap { remoteItem in
            guard let extrinsicHash = remoteItem.extrinsicHash else {
                return nil
            }

            return try? Data(hexStringSSF: extrinsicHash)
        }

        let existingHashes = Set(remoteHashes)
        let hashesToRemove = Self.identifiersToRemove(
            remoteHashes: existingHashes,
            oldestRemoteTimestamp: remoteItems.last?.itemTimestamp,
            localItems: localItems
        )

        let filterSet = Set(hashesToRemove)
        let visibleLocalItems: [TransactionHistoryItem] = localItems.compactMap { item in
            guard !filterSet.contains(item.txHash) else {
                return nil
            }

            return item
        }
        let journalOverlayItems = Self.pendingJournalOverlay(
            address: address,
            submissions: pendingSubmissions,
            visibleLocalItems: visibleLocalItems,
            remoteHashes: existingHashes
        )
        let localMergeItems: [TransactionHistoryMergeItem] =
            (visibleLocalItems + journalOverlayItems).map {
                TransactionHistoryMergeItem.local(item: $0)
            }

        let remoteMergeItems: [TransactionHistoryMergeItem] = remoteItems.map {
            TransactionHistoryMergeItem.remote(remote: $0)
        }

        let transactionsItems = (localMergeItems + remoteMergeItems)
            .sorted { $0.compareWithItem($1) }
            .compactMap { item in
                item.buildTransactionData(
                    address: address,
                    networkType: networkType,
                    asset: asset,
                    addressFactory: addressFactory
                )
            }

        let results = TransactionHistoryMergeResult(
            historyItems: transactionsItems,
            identifiersToRemove: hashesToRemove
        )

        return results
    }

    /// Projects the durable signed-submission journal into the normal SORA2
    /// history without reconstructing a call, amount, or fee. A richer Core
    /// Data overlay for the same exact hash wins; an exact PI hash suppresses
    /// the journal row. Indexer age alone never suppresses a journal witness.
    static func pendingJournalOverlay(
        address: String,
        submissions: [Sora2PendingSubmission],
        visibleLocalItems: [TransactionHistoryItem],
        remoteHashes: Set<Data>
    ) -> [TransactionHistoryItem] {
        guard !address.isEmpty else {
            return []
        }

        var occupiedHashes = remoteHashes
        visibleLocalItems.forEach { item in
            if let hash = normalizedHashData(item.txHash) {
                occupiedHashes.insert(hash)
            }
        }

        var overlay: [TransactionHistoryItem] = []
        for submission in submissions where submission.account == address {
            guard
                let canonicalHash = Sora2PendingSubmissionStore
                    .normalizedHash(submission.extrinsicHash),
                let hashData = normalizedHashData(canonicalHash),
                !occupiedHashes.contains(hashData),
                submission.recoveryContext?.isValid(
                    account: submission.account,
                    hash: canonicalHash
                ) != false,
                isValidTerminalResolution(submission),
                let timestamp = exactTimestamp(submission.createdAt)
            else {
                continue
            }

            let status: TransactionHistoryItem.Status
            switch submission.terminalResolution?.kind {
            case .finalizedSuccess:
                status = .success
            case .finalizedFailure, .expiredNotIncluded:
                status = .failed
            case .none:
                status = .pending
            }

            let blockNumber = submission.terminalResolution?.blockNumber
                .flatMap { UInt64(exactly: $0) }
            overlay.append(
                TransactionHistoryItem(
                    sender: address,
                    receiver: nil,
                    status: status,
                    txHash: "0x\(canonicalHash)",
                    timestamp: timestamp,
                    fee: "0",
                    blockNumber: blockNumber,
                    txIndex: nil,
                    callPath: CallCodingPath(
                        moduleName: "SORA2",
                        callName: "pending_submission"
                    ),
                    call: Data()
                )
            )
            occupiedHashes.insert(hashData)
        }
        return overlay
    }

    private static func normalizedHashData(_ value: String) -> Data? {
        guard
            let canonical = Sora2PendingSubmissionStore.normalizedHash(value)
        else {
            return nil
        }
        return try? Data(hexStringSSF: canonical)
    }

    private static func isValidTerminalResolution(
        _ submission: Sora2PendingSubmission
    ) -> Bool {
        guard let resolution = submission.terminalResolution else {
            return true
        }
        guard
            submission.state == .submitted,
            let context = submission.recoveryContext
        else {
            return false
        }
        return resolution.isValid(for: context)
    }

    private static func exactTimestamp(_ date: Date) -> Int64? {
        let value = date.timeIntervalSince1970
        guard
            value.isFinite,
            value > Double(Int64.min),
            value < Double(Int64.max)
        else {
            return nil
        }
        return Int64(value)
    }

    /// Pending submissions are removed only by an exact remote hash match.
    /// Their age relative to a paginated indexer response cannot prove that
    /// transport did not happen or that PI has caught up yet.
    static func identifiersToRemove(
        remoteHashes: Set<Data>,
        oldestRemoteTimestamp: Int64?,
        localItems: [TransactionHistoryItem]
    ) -> [String] {
        localItems.compactMap { item in
            if let localHash = try? Data(hexStringSSF: item.txHash), remoteHashes.contains(localHash) {
                return item.txHash
            }

            guard item.status != .pending,
                  let oldestRemoteTimestamp else {
                return nil
            }

            if item.timestamp < oldestRemoteTimestamp {
                return item.txHash
            }

            return nil
        }
    }
}
