import Foundation

struct NewTransactionCreatedEvent: EventProtocol {
    let item: Transaction
    init(item: Transaction) {
        self.item = item
    }
    func accept(visitor: EventVisitorProtocol) {
        visitor.processNewTransactionCreated(event: self)
    }
}
