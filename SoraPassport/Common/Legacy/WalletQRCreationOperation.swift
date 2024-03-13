/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import CoreImage
import RobinHood
import UIKit

enum WalletQRCreationOperationError: Error {
    case generatorUnavailable
    case generatedImageInvalid
    case bitmapImageCreationFailed
}

public final class WalletQRCreationOperation: BaseOperation<UIImage> {
    let payload: Data
    let qrSize: CGSize

    init(payload: Data, qrSize: CGSize) {
        self.payload = payload
        self.qrSize = qrSize

        super.init()
    }

    override public func main() {
        super.main()

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            if !isCancelled {
                result = .failure(WalletQRCreationOperationError.generatorUnavailable)
            }

            return
        }

        filter.setValue(payload, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let qrImage = filter.outputImage else {
            if !isCancelled {
                result = .failure(WalletQRCreationOperationError.generatedImageInvalid)
            }

            return
        }

        let transformedImage: CIImage

        if qrImage.extent.size.width * qrImage.extent.height > 0.0 {
            let transform = CGAffineTransform(scaleX: qrSize.width / qrImage.extent.width,
                                              y: qrSize.height / qrImage.extent.height)
            transformedImage = qrImage.transformed(by: transform)
        } else {
            transformedImage = qrImage
        }

        let context = CIContext()

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            if !isCancelled {
                result = .failure(WalletQRCreationOperationError.bitmapImageCreationFailed)
            }

            return
        }


        if !isCancelled {
            result = .success(UIImage(cgImage: cgImage))
        }
    }
}
