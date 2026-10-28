/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol WalletQREncoderProtocol {
    func encode(receiverInfo: ReceiveInfo) throws -> Data
}

public protocol WalletQRDecoderProtocol {
    func decode(data: Data) throws -> ReceiveInfo
}

public protocol WalletQRCoderFactoryProtocol {
    func createEncoder() -> WalletQREncoderProtocol
    func createDecoder() -> WalletQRDecoderProtocol
}
