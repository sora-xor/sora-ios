/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol WalletQROperationFactoryProtocol: AnyObject {
    func createCreationOperation(for payload: Data, qrSize: CGSize) -> WalletQRCreationOperation
}

public final class WalletQROperationFactory: WalletQROperationFactoryProtocol {
    public init() {}
    public func createCreationOperation(for payload: Data, qrSize: CGSize) -> WalletQRCreationOperation {
        return WalletQRCreationOperation(payload: payload, qrSize: qrSize)
    }
}
