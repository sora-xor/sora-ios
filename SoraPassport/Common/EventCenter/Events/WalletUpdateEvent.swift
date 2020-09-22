import Foundation

struct WalletUpdateEvent: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletUpdate(event: self)
    }
}
