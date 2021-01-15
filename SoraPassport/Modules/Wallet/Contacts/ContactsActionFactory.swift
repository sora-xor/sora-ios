/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

private class SendOptionViewModel: SendOptionViewModelProtocol {
    let title: String
    let icon: UIImage?
    let command: WalletCommandProtocol?

    init(command: WalletCommandProtocol, title: String, icon: UIImage?) {
        self.command = command
        self.title = title
        self.icon = icon
    }
}

final class ContactsActionFactory: ContactsActionFactoryWrapperProtocol {
    let ethAddress: String

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(ethAddress: String) {
        self.ethAddress = ethAddress
    }

    func createOptionListForAccountId(_ accountId: String,
                                      assetId: String,
                                      locale: Locale?) -> [SendOptionViewModelProtocol]? {
        let receiver = ReceiveInfo(accountId: ethAddress,
                                   assetId: assetId,
                                   amount: nil,
                                   details: nil)

        let payload = TransferPayload(receiveInfo: receiver,
                                      receiverName: ethAddress)

        guard let command = commandFactory?.prepareTransfer(with: payload) else {
            return nil
        }

        command.presentationStyle = .push(hidesBottomBar: true)

        let title = R.string.localizable
            .walletValToMyEth(preferredLanguages: locale?.rLanguages)
        let icon = R.image.iconValErc()

        let sendAction = SendOptionViewModel(command: command,
                                             title: title,
                                             icon: icon)

        return [sendAction]
    }
}
