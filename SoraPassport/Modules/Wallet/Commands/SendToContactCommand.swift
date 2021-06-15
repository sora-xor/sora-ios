import Foundation
import SoraFoundation
import CommonWallet

class SendToContactCommand: WalletCommandProtocol {

    private let nextActionBlock: () -> Void

    init(nextAction nextActionBlock: @escaping () -> Void) {
        self.nextActionBlock = nextActionBlock
    }

    func execute() throws {
        self.nextActionBlock()
    }
}
