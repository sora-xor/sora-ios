// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import UIKit

protocol WalletQRExtractionServiceProtocol {
    func extract(from image: UIImage,
                 using matcher: WalletQRMatcherProtocol,
                 dispatchCompletionIn queue: DispatchQueue?,
                 completionBlock: @escaping (Result<String, Error>) -> Void)
}

enum WalletQRExtractionServiceError: Error {
    case invalidImage
    case detectorUnavailable
    case noFeatures
}

final class WalletQRExtractionService {
    private let processingQueue: DispatchQueue

    init(processingQueue: DispatchQueue) {
        self.processingQueue = processingQueue
    }

    private func proccess(image: UIImage, with matcher: WalletQRMatcherProtocol) -> Result<String, Error> {
        var optionalImage: CIImage?

        if let ciImage = CIImage(image: image) {
            optionalImage = ciImage
        } else if let cgImage = image.cgImage {
            optionalImage = CIImage(cgImage: cgImage)
        }

        guard let ciImage = optionalImage else {
            return .failure(WalletQRExtractionServiceError.invalidImage)
        }

        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        guard let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                        context: nil,
                                        options: options) else {
            return .failure(WalletQRExtractionServiceError.detectorUnavailable)
        }

        let features = detector.features(in: ciImage)

        let optionalMatch: String? = features
                .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
                .first { matcher.match(code: $0) }

        guard let match = optionalMatch else {
            return .failure(WalletQRExtractionServiceError.noFeatures)
        }

        return .success(match)
    }
}

extension WalletQRExtractionService: WalletQRExtractionServiceProtocol {
    func extract(from image: UIImage,
                 using matcher: WalletQRMatcherProtocol,
                 dispatchCompletionIn queue: DispatchQueue?,
                 completionBlock: @escaping (Result<String, Error>) -> Void) {
        processingQueue.async {
            let result = self.proccess(image: image, with: matcher)

            if let queue = queue {
                queue.async {
                    completionBlock(result)
                }
            } else {
                completionBlock(result)
            }
        }
    }
}
