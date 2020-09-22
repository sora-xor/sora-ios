import Foundation
import RobinHood
import CommonWallet

protocol WalletHistoryMergeItem {
    var timestamp: Int64 { get }

    func accept(visitor: WalletHistoryMergeItemVisitor)
    func toAssetTransaction() -> AssetTransactionData
}

extension AssetTransactionData: WalletHistoryMergeItem {
    func accept(visitor: WalletHistoryMergeItemVisitor) {
        visitor.visit(remote: self)
    }

    func toAssetTransaction() -> AssetTransactionData {
        self
    }
}

extension TransferOperationData: WalletHistoryMergeItem {
    func accept(visitor: WalletHistoryMergeItemVisitor) {
        visitor.visit(transfer: self)
    }

    func toAssetTransaction() -> AssetTransactionData {
        AssetTransactionData(transfer: self)
    }
}

extension WithdrawOperationData: WalletHistoryMergeItem {
    func accept(visitor: WalletHistoryMergeItemVisitor) {
        visitor.visit(withdraw: self)
    }

    func toAssetTransaction() -> AssetTransactionData {
        AssetTransactionData(withdraw: self)
    }
}

extension DepositOperationData: WalletHistoryMergeItem {
    func accept(visitor: WalletHistoryMergeItemVisitor) {
        visitor.visit(deposit: self)
    }

    func toAssetTransaction() -> AssetTransactionData {
        AssetTransactionData(deposit: self)
    }
}

final class WalletHistoryMergeItemVisitor {
    private(set) var ignoringIds: Set<String>
    private var includedRemote: [String: AssetTransactionData] = [:]
    private var includedTransfers: [String: TransferOperationData] = [:]
    private var includedWithdraws: [String: WithdrawOperationData] = [:]
    private var includedDeposits: [String: DepositOperationData] = [:]

    var allItems: [WalletHistoryMergeItem] {
        includedRemote.map { $1 } + includedTransfers.map { $1 } +
        includedWithdraws.map { $1} + includedDeposits.map { $1 }
    }

    init(ignoringIds: Set<String>) {
        self.ignoringIds = ignoringIds
    }

    func visit(remote: AssetTransactionData) {
        guard !ignoringIds.contains(remote.transactionId) else {
            return
        }

        if remote.type == WalletTransactionTypeValue.deposit.rawValue {
            guard !ignoringIds.contains(remote.details) else {
                return
            }

            ignoringIds.insert(remote.details)
        }

        includedRemote[remote.transactionId] = remote
    }

    func isRemoteIgnored(_ remote: AssetTransactionData) -> Bool {
        includedRemote[remote.transactionId] == nil
    }

    func visit(transfer: TransferOperationData) {
        includedTransfers[transfer.identifier] = transfer
    }

    func isTransferIgnored(_ transfer: TransferOperationData) -> Bool {
        includedTransfers[transfer.transactionId] == nil
    }

    func visit(withdraw: WithdrawOperationData) {
        includedRemote[withdraw.intentTransactionId] = nil

        includedWithdraws[withdraw.intentTransactionId] = withdraw
        ignoringIds.insert(withdraw.intentTransactionId)
    }

    func isWithdrawIgnored(_ withdraw: WithdrawOperationData) -> Bool {
        includedWithdraws[withdraw.intentTransactionId] == nil
    }

    func visit(deposit: DepositOperationData) {
        guard !ignoringIds.contains(deposit.depositTransactionId) else {
            return
        }

        ignoringIds.insert(deposit.depositTransactionId)

        if let transactionId = deposit.transferTransactionId {
            ignoringIds.insert(transactionId)
        }

        includedDeposits[deposit.depositTransactionId] = deposit
    }

    func isDepositIgnored(_ deposit: DepositOperationData) -> Bool {
        includedDeposits[deposit.depositTransactionId] == nil
    }
}

final class WalletHistoryMergeOperation: BaseOperation<AssetTransactionPageData?> {
    let context: WalletHistoryContext
    let size: Int

    var remoteTransactions: [AssetTransactionData] = []
    var transfers: [TransferOperationData] = []
    var withdraws: [WithdrawOperationData] = []
    var deposits: [DepositOperationData] = []

    init(size: Int, context: WalletHistoryContext) {
        self.context = context
        self.size = size

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        let allItems: [WalletHistoryMergeItem] = (remoteTransactions + transfers + withdraws + deposits)
            .sorted { $0.timestamp > $1.timestamp }

        let visitor = WalletHistoryMergeItemVisitor(ignoringIds: context.ignoringIds)
        allItems.reversed().forEach { $0.accept(visitor: visitor) }

        let filteredItems = visitor.allItems
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(size)

        let context = calculateContextFromVisitor(visitor, filteredItems: Array(filteredItems))
        let transactions = filteredItems.map { $0.toAssetTransaction() }
        let page = AssetTransactionPageData(transactions: transactions, context: context)

        result = .success(page)
    }

    private func calculateContextFromVisitor(_ visitor: WalletHistoryMergeItemVisitor,
                                             filteredItems: [WalletHistoryMergeItem])
        -> WalletHistoryContext? {

        let remoteOffset = calculateNewRemoteOffset(context.remoteOffset,
                                                    filteredItems: filteredItems,
                                                    visitor: visitor)

        let transferOffset = calculateNewTransferOffset(context.transferOffset,
                                                        filteredItems: filteredItems,
                                                        visitor: visitor)

        let withdrawOffset = calculateNewWithdrawOffset(context.withdrawOffset,
                                                        filteredItems: filteredItems,
                                                        visitor: visitor)

        let depositOffset = calculateNewDepositsOffset(context.depositOffset,
                                                       filteredItems: filteredItems,
                                                       visitor: visitor)

        if remoteOffset == nil, transferOffset == nil, withdrawOffset == nil, depositOffset == nil {
            return nil
        } else {
            return WalletHistoryContext(ignoringIds: visitor.ignoringIds,
                                        remoteOffset: remoteOffset,
                                        transferOffset: transferOffset,
                                        withdrawOffset: withdrawOffset,
                                        depositOffset: depositOffset)
        }
    }

    private func calculateNewRemoteOffset(_ oldOffset: Int?,
                                          filteredItems: [WalletHistoryMergeItem],
                                          visitor: WalletHistoryMergeItemVisitor) -> Int? {
        guard let currentOffset = oldOffset else {
            return nil
        }

        var newOffset = currentOffset

        if
            let lastRemote = filteredItems
                .last(where: { $0 is AssetTransactionData }) as? AssetTransactionData,
            let itemIndex = remoteTransactions
                .firstIndex(where: { $0.transactionId == lastRemote.transactionId }) {
            let skipIndex = remoteTransactions[itemIndex+1..<remoteTransactions.count]
                .firstIndex { !visitor.isRemoteIgnored($0) } ?? 0
            newOffset += itemIndex + skipIndex + 1
        }

        if newOffset == currentOffset + remoteTransactions.count, remoteTransactions.count < size {
            return nil
        }

        return newOffset
    }

    private func calculateNewTransferOffset(_ oldOffset: Int?,
                                            filteredItems: [WalletHistoryMergeItem],
                                            visitor: WalletHistoryMergeItemVisitor) -> Int? {
        guard let currentOffset = oldOffset else {
            return nil
        }

        var newOffset = currentOffset

        if
            let lastTransfer = filteredItems
                .last(where: { $0 is TransferOperationData }) as? TransferOperationData,
            let itemIndex = transfers
                .firstIndex(where: { $0.transactionId == lastTransfer.transactionId }) {
            let skipIndex = transfers[itemIndex+1..<transfers.count]
                .firstIndex { !visitor.isTransferIgnored($0) } ?? 0
            newOffset += itemIndex + skipIndex + 1
        }

        if newOffset == currentOffset + transfers.count, transfers.count < size {
            return nil
        }

        return newOffset
    }

    private func calculateNewWithdrawOffset(_ oldOffset: Int?,
                                            filteredItems: [WalletHistoryMergeItem],
                                            visitor: WalletHistoryMergeItemVisitor) -> Int? {
        guard let currentOffset = oldOffset else {
            return nil
        }

        var newOffset = currentOffset

        if
            let lastWithdraw = filteredItems
                .last(where: { $0 is WithdrawOperationData }) as? WithdrawOperationData,
            let itemIndex = withdraws
                .firstIndex(where: { $0.intentTransactionId == lastWithdraw.intentTransactionId }) {
            let skipIndex = withdraws[itemIndex+1..<withdraws.count]
                .firstIndex { !visitor.isWithdrawIgnored($0) } ?? 0
            newOffset += itemIndex + skipIndex + 1
        }

        if newOffset == currentOffset + withdraws.count, withdraws.count < size {
            return nil
        }

        return newOffset
    }

    private func calculateNewDepositsOffset(_ oldOffset: Int?,
                                            filteredItems: [WalletHistoryMergeItem],
                                            visitor: WalletHistoryMergeItemVisitor) -> Int? {
        guard let currentOffset = oldOffset else {
            return nil
        }

        var newOffset = currentOffset

        if
            let lastDeposit = filteredItems
                .last(where: { $0 is DepositOperationData }) as? DepositOperationData,
            let itemIndex = deposits
                .firstIndex(where: { $0.depositTransactionId == lastDeposit.depositTransactionId }) {
            let skipIndex = deposits[itemIndex+1..<deposits.count]
                .firstIndex { !visitor.isDepositIgnored($0) } ?? 0
            newOffset += itemIndex + skipIndex + 1
        }

        if newOffset == currentOffset + deposits.count, deposits.count < size {
            return nil
        }

        return newOffset
    }
}
