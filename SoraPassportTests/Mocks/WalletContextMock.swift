import Foundation
import CommonWallet

class WalletCommandMock: WalletCommandProtocol {
    private(set) var executionCount: Int = 0

    func execute() throws {
        executionCount += 1
    }
}

class WalletPresentationCommandMock: WalletCommandMock, WalletPresentationCommandProtocol {
    var completionBlock: (() -> Void)?
    
    var presentationStyle: WalletPresentationStyle = .modal(inNavigation: true)
    var animated: Bool = true
}

class WalletHideCommandMock: WalletCommandMock, WalletHideCommandProtocol {
    var completionBlock: (() -> Void)?
    
    var actionType: WalletHideActionType = .dismiss
    var animated: Bool = true
}

class AssetDetailsCommandMock: WalletPresentationCommandMock, AssetDetailsCommadProtocol {
    var ignoredWhenSingleAsset: Bool = true
}

final class WalletContextMock: CommonWalletContextProtocol {
    var networkOperationFactory: WalletNetworkOperationFactoryProtocol {get {return WalletNetworkOperationFactoryProtocolMock()}}

    var closureCreateRootController: (() -> UINavigationController)?
    var closurePrepareSendCommand: ((String?) -> WalletPresentationCommandProtocol)?
    var closurePrepareReceiveCommand: ((String?) -> WalletPresentationCommandProtocol)?
    var closurePrepareAssetDetailsCommand: ((String) -> AssetDetailsCommadProtocol)?
    var closurePrepareScanReceiverCommand: (() -> AssetDetailsCommadProtocol)?
    var closurePrepareWithdrawCommand: ((String, String) -> WalletPresentationCommandProtocol)?
    var closurePreparePresentationCommand: ((UIViewController) -> WalletPresentationCommandProtocol)?
    var closurePrepareAccountUpdateCommand: (() -> WalletCommandProtocol)?
    var closurePrepareHideCommand: ((WalletHideActionType) -> WalletHideCommandProtocol)?
    var closurePrepareLanguageSwitch: ((WalletLanguage) -> WalletCommandProtocol)?
    var closurePrepareTxDetailsCommand: ((AssetTransactionData) -> WalletPresentationCommandProtocol)?
    var closurePrepareTransferCommand: ((TransferPayload) -> WalletPresentationCommandProtocol)?

    func createRootController() throws -> UINavigationController {
        return closureCreateRootController?() ?? UINavigationController()
    }

    func prepareSendCommand(for assetId: String?) -> WalletPresentationCommandProtocol {
        return closurePrepareSendCommand?(assetId) ?? WalletPresentationCommandMock()
    }

    func prepareReceiveCommand(for assetId: String?) -> WalletPresentationCommandProtocol {
        return closurePrepareReceiveCommand?(assetId) ?? WalletPresentationCommandMock()
    }

    func prepareAssetDetailsCommand(for assetId: String) -> AssetDetailsCommadProtocol {
        return closurePrepareAssetDetailsCommand?(assetId) ?? AssetDetailsCommandMock()
    }

    func prepareScanReceiverCommand() -> WalletPresentationCommandProtocol {
        return closurePrepareScanReceiverCommand?() ?? WalletPresentationCommandMock()
    }

    func prepareWithdrawCommand(for assetId: String, optionId: String) -> WalletPresentationCommandProtocol {
        return closurePrepareWithdrawCommand?(assetId, optionId) ?? WalletPresentationCommandMock()
    }

    func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommandProtocol {
        return closurePreparePresentationCommand?(controller) ?? WalletPresentationCommandMock()
    }

    func prepareAccountUpdateCommand() -> WalletCommandProtocol {
        return closurePrepareAccountUpdateCommand?() ?? WalletCommandMock()
    }

    func prepareHideCommand(with actionType: WalletHideActionType) -> WalletHideCommandProtocol {
        return closurePrepareHideCommand?(actionType) ?? WalletHideCommandMock()
    }

    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol {
        return closurePrepareLanguageSwitch?(newLanguage) ?? WalletCommandMock()
    }

    func prepareTransactionDetailsCommand(with transaction: AssetTransactionData)
        -> WalletPresentationCommandProtocol {
        return closurePrepareTxDetailsCommand?(transaction) ?? WalletPresentationCommandMock()
    }

    func prepareTransfer(with payload: TransferPayload) -> WalletPresentationCommandProtocol {
        return closurePrepareTransferCommand?(payload) ?? WalletPresentationCommandMock()
    }
    
    func prepareConfirmation(with payload: ConfirmationPayload) -> WalletPresentationCommandProtocol {
        WalletPresentationCommandMock()
    }

}
