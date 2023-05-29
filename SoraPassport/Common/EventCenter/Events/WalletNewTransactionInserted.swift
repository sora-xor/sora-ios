import Foundation

struct WalletNewTransactionInserted: EventProtocol {
    let items: [TransactionSubscriptionResult]
    init(items: [TransactionSubscriptionResult]) {
        self.items = items
    }
    func accept(visitor: EventVisitorProtocol) {
        visitor.processNewTransaction(event: self)
    }
}
