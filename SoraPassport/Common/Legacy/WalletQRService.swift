/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import RobinHood
import UIKit

public protocol WalletQRServiceProtocol: AnyObject {
    @discardableResult
    func generate(from info: ReceiveInfo,
                  qrSize: CGSize,
                  runIn queue: DispatchQueue,
                  completionBlock: @escaping (Result<UIImage, Error>?) -> Void) throws -> Operation
}

public final class WalletQRService {
    let operationFactory: WalletQROperationFactoryProtocol
    let operationQueue: OperationQueue

    private let encoder: WalletQREncoderProtocol

    public init(operationFactory: WalletQROperationFactoryProtocol,
                encoder: WalletQREncoderProtocol,
                operationQueue: OperationQueue = OperationQueue()) {
        self.operationFactory = operationFactory
        self.encoder = encoder
        self.operationQueue = operationQueue
    }
}

extension WalletQRService: WalletQRServiceProtocol {
    @discardableResult
    public func generate(from info: ReceiveInfo,
                         qrSize: CGSize,
                         runIn queue: DispatchQueue,
                         completionBlock: @escaping (Result<UIImage, Error>?) -> Void) throws -> Operation {
        let payload = try encoder.encode(receiverInfo: info)
        let operation = operationFactory.createCreationOperation(for: payload, qrSize: qrSize)

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        operationQueue.addOperation(operation)
        return operation
    }
}
