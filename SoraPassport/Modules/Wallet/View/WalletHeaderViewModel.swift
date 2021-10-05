import Foundation
import CommonWallet

final class WalletHeaderViewModel {
    weak var walletContext: CommonWalletContextProtocol? {
        didSet {
            setCommands()
        }
    }
    private(set) var walletWireframe: WalletWireframeProtocol
    let commandDecorator: WalletCommandDecoratorFactoryProtocol

    init(walletWireframe: WalletWireframeProtocol,
         commandDecorator: WalletCommandDecoratorFactoryProtocol) {
        self.walletWireframe = walletWireframe
        self.commandDecorator = commandDecorator
    }

    var sendCommand: WalletCommandProtocol?
    var receiveCommand: WalletCommandProtocol?
    var manageCommand: WalletCommandProtocol?
    var scanCommand: WalletCommandProtocol?

    func setCommands() {
        let sCommand = walletContext?.prepareSendCommand(for: nil)
        let rCommand = walletContext?.prepareReceiveCommand(for: nil)

        if let context = walletContext,
            let commandFactory = context as? WalletCommandFactoryProtocol,
            let sendDecorator = commandDecorator.createSendCommandDecorator(with: commandFactory),
            let receiveDecorator = commandDecorator.createReceiveCommandDecorator(with: commandFactory) {
            sendDecorator.undelyingCommand = sCommand
            sendCommand = sendDecorator

            receiveDecorator.undelyingCommand = rCommand
            receiveCommand = receiveDecorator
            if let customFactory = commandDecorator as? WalletCommandDecoratorFactory {
                manageCommand = customFactory.createManageCommandDecorator(with: commandFactory)
                scanCommand = customFactory.createScanCommandDecorator(with: commandFactory)
            }
        }

    }

    public func presentHelp() {
        if let context = walletContext {
            walletWireframe.presentHelp(in: context)
        }
    }
}

extension WalletHeaderViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String {
        return R.reuseIdentifier.walletAccountHeaderId.identifier
    }

    var itemHeight: CGFloat {
        return 73.0
    }

    var command: WalletCommandProtocol? {
        return nil //tap on header executes this
    }
}
