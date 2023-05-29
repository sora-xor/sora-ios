import Foundation

protocol LocalTransactionStorageProtocol {
    var transactions: [String: [Transaction]] { get set }
}

final class LocalTransactionStorage: LocalTransactionStorageProtocol {
    
    static let shared = LocalTransactionStorage()
    var transactions: [String: [Transaction]] = [:]
    var currentAccount = SelectedWalletSettings.shared
    
    init() {
        EventCenter.shared.add(observer: self)
    }
}

extension LocalTransactionStorage: EventVisitorProtocol {
    func processNewTransactionCreated(event: NewTransactionCreatedEvent) {
        guard let address = currentAccount.currentAccount?.address else { return }
        var transactions = transactions[address] ?? []
        transactions.append(event.item)
        self.transactions[address] = transactions
    }
    
    func processNewTransaction(event: WalletNewTransactionInserted) {
        if let transaction = event.items.first,
           let address = currentAccount.currentAccount?.address,
           var transactions = transactions[address],
           var foundedTransactionIndex = transactions.firstIndex(where: { $0.base.txHash == transaction.extrinsicHash.toHex(includePrefix: true) }) {
            
            transactions[foundedTransactionIndex].base.status = transaction.processingResult.isSuccess ? .success : .failed
            self.transactions[address] = transactions
        }
    }
}
