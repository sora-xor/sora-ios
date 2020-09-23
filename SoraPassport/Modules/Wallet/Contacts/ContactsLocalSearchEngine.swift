/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

private final class ContactViewModel: ContactsLocalSearchResultProtocol {
    let firstName: String
    let lastName: String
    let accountId: String
    let image: UIImage?
    let name: String
    let command: WalletCommandProtocol?

    init(firstName: String,
         lastName: String,
         accountId: String,
         image: UIImage?,
         name: String,
         command: WalletCommandProtocol?) {
        self.firstName = firstName
        self.lastName = lastName
        self.accountId = accountId
        self.image = image
        self.name = name
        self.command = command
    }
}

final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {

    weak var commandFactory: WalletCommandFactoryProtocol?

    func search(query: String, assetId: String) -> [ContactViewModelProtocol]? {
        guard NSPredicate.ethereumAddress.evaluate(with: query) else {
            return nil
        }

        let receiver = ReceiveInfo(accountId: query,
                                   assetId: nil,
                                   amount: nil,
                                   details: nil)

        let payload = TransferPayload(receiveInfo: receiver,
                                      receiverName: query)

        guard let command = commandFactory?.prepareTransfer(with: payload) else {
            return nil
        }

        command.presentationStyle = .push(hidesBottomBar: true)

        let result = ContactViewModel(firstName: query,
                                      lastName: "",
                                      accountId: query,
                                      image: R.image.iconEth(),
                                      name: query,
                                      command: command)

        return [result]
    }
}
