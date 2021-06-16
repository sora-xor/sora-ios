/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
