/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import IrohaCommunication

class WalletCommandMock: WalletCommandProtocol {
    private(set) var executionCount: Int = 0

    func execute() throws {
        executionCount += 1
    }
}

class WalletPresentationCommandMock: WalletCommandMock, WalletPresentationCommandProtocol {
    var presentationStyle: WalletPresentationStyle = .modal(inNavigation: true)
    var animated: Bool = true
}

class WalletHideCommandMock: WalletCommandMock, WalletHideCommandProtocol {
    var actionType: WalletHideActionType = .dismiss
    var animated: Bool = true
}

class AssetDetailsCommandMock: WalletPresentationCommandMock, AssetDetailsCommadProtocol {
    var ignoredWhenSingleAsset: Bool = true
}

final class WalletContextMock: CommonWalletContextProtocol {
    var closureCreateRootController: (() -> UINavigationController)?
    var closurePrepareSendCommand: ((IRAssetId?) -> WalletPresentationCommandProtocol)?
    var closurePrepareReceiveCommand: ((IRAssetId?) -> WalletPresentationCommandProtocol)?
    var closurePrepareAssetDetailsCommand: ((IRAssetId) -> AssetDetailsCommadProtocol)?
    var closurePrepareScanReceiverCommand: (() -> AssetDetailsCommadProtocol)?
    var closurePrepareWithdrawCommand: ((IRAssetId, String) -> WalletPresentationCommandProtocol)?
    var closurePreparePresentationCommand: ((UIViewController) -> WalletPresentationCommandProtocol)?
    var closurePrepareAccountUpdateCommand: (() -> WalletCommandProtocol)?
    var closurePrepareHideCommand: ((WalletHideActionType) -> WalletHideCommandProtocol)?
    var closurePrepareLanguageSwitch: ((WalletLanguage) -> WalletCommandProtocol)?

    func createRootController() throws -> UINavigationController {
        return closureCreateRootController?() ?? UINavigationController()
    }

    func prepareSendCommand(for assetId: IRAssetId?) -> WalletPresentationCommandProtocol {
        return closurePrepareSendCommand?(assetId) ?? WalletPresentationCommandMock()
    }

    func prepareReceiveCommand(for assetId: IRAssetId?) -> WalletPresentationCommandProtocol {
        return closurePrepareReceiveCommand?(assetId) ?? WalletPresentationCommandMock()
    }

    func prepareAssetDetailsCommand(for assetId: IRAssetId) -> AssetDetailsCommadProtocol {
        return closurePrepareAssetDetailsCommand?(assetId) ?? AssetDetailsCommandMock()
    }

    func prepareScanReceiverCommand() -> WalletPresentationCommandProtocol {
        return closurePrepareScanReceiverCommand?() ?? WalletPresentationCommandMock()
    }

    func prepareWithdrawCommand(for assetId: IRAssetId, optionId: String) -> WalletPresentationCommandProtocol {
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
}
