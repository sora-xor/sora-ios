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

import UIKit
import Kingfisher

protocol ImageViewModelProtocol: AnyObject {
    var image: UIImage? { get }

    var targetSize: CGSize? { get set }
    var cornerRadius: CGFloat? { get set }
    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void)
    func cancel()

    func isEqual(to viewModel: ImageViewModelProtocol) -> Bool
}

final class ImageViewModel: NSObject {
    private var url: URL

    private var imageTask: DownloadTask?

    var targetSize: CGSize?

    var cornerRadius: CGFloat?

    init(url: URL) {
        self.url = url
    }
}

extension ImageViewModel: ImageViewModelProtocol {
    var image: UIImage? {

        let options: KingfisherOptionsInfo = [.callbackQueue(.mainCurrentOrAsync),
                                              .processor(self)]

        if let currentImage = KingfisherManager.shared.cache
            .retrieveImageInMemoryCache(forKey: url.absoluteString, options: options) {
            return currentImage
        }

        return nil
    }

    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void) {
        let imageResource = Kingfisher.ImageResource(downloadURL: url)

        let options: KingfisherOptionsInfo = [.callbackQueue(.mainCurrentOrAsync),
                                              .cacheSerializer(FormatIndicatedCacheSerializer.png),
                                              .processor(self)]

        imageTask?.cancel()

        imageTask = KingfisherManager.shared.retrieveImage(with: imageResource,
                                                           options: options,
                                                           progressBlock: nil) { result in
            switch result {
            case .success(let value):
                completionBlock(value.image, nil)
            case .failure(let error):
                completionBlock(nil, error)
            }
        }
    }

    func isEqual(to viewModel: ImageViewModelProtocol) -> Bool {
        guard let otherViewModel = viewModel as? ImageViewModel else {
            return false
        }

        return url == otherViewModel.url &&
            cornerRadius == otherViewModel.cornerRadius &&
            targetSize == otherViewModel.targetSize
    }

    func cancel() {
        imageTask?.cancel()
        imageTask = nil
    }
}

extension ImageViewModel: ImageProcessor {

    var identifier: String {
        return ProcessorIdentifier.identifier(from: targetSize, cornerRadius: cornerRadius)
    }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        var resultItem = item

        if let size = targetSize {
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                return nil
            }
            let resizeProcessor = ResizingImageProcessor(referenceSize: size, mode: .aspectFill)
//            let options: KingfisherParsedOptionsInfo = [.scaleFactor(scaleFactor)]

            guard let resizedImage = resizeProcessor.process(item: item, options: options) else {
                return nil
            }

            // A CGImage crop rounds a half-pixel origin outwards, which can
            // add a row or column. Draw into the requested canvas instead.
            let format = UIGraphicsImageRendererFormat()
            format.scale = resizedImage.scale
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            resultItem = .image(renderer.image { _ in
                resizedImage.draw(at: CGPoint(x: (size.width - resizedImage.size.width) / 2,
                                              y: (size.height - resizedImage.size.height) / 2))
            })
        }

        if let radius = cornerRadius {
            let cornerProccessor = RoundCornerImageProcessor(cornerRadius: radius,
                                                             targetSize: nil,
                                                             roundingCorners: [.topLeft, .topRight],
                                                             backgroundColor: nil)

            guard let roundedImage = cornerProccessor.process(item: resultItem,
                                                              options: options) else {
                return nil
            }

            resultItem = .image(roundedImage)
        }

        switch resultItem {
        case .image(let image):
            return image
        case .data(let data):
            return KFCrossPlatformImage(data: data)
        }
    }
}

private struct ProcessorIdentifier {
    static let emptyField = "empty"
    static let widthField = "w"
    static let heightField = "h"
    static let cornerRadiusField = "h"
    static let separator = "_"

    static func identifier(from targetSize: CGSize?, cornerRadius: CGFloat?) -> String {
        var result = "image-v2_"

        if let targetSize = targetSize {
            result += "\(ProcessorIdentifier.widthField)\(ProcessorIdentifier.separator)\(Double(targetSize.width))"
            result += "\(ProcessorIdentifier.heightField)\(ProcessorIdentifier.separator)\(Double(targetSize.height))"
        } else {
            result += "\(ProcessorIdentifier.widthField)\(ProcessorIdentifier.separator)"
            result += "\(ProcessorIdentifier.emptyField)"
            result += "\(ProcessorIdentifier.heightField)\(ProcessorIdentifier.separator)"
            result += "\(ProcessorIdentifier.emptyField)"
        }

        result += ProcessorIdentifier.separator

        if let cornerRadius = cornerRadius {
            result += "\(ProcessorIdentifier.cornerRadiusField)\(ProcessorIdentifier.separator)\(Double(cornerRadius))"
        } else {
            result += "\(ProcessorIdentifier.cornerRadiusField)\(ProcessorIdentifier.separator)"
            result += "\(ProcessorIdentifier.emptyField)"
        }

        return result
    }
}
