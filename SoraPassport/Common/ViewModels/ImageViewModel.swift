/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Kingfisher

protocol ImageViewModelProtocol: class {
    var image: UIImage? { get }

    var targetSize: CGSize? { get set }
    var cornerRadius: CGFloat? { get set }
    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void)
    func cancel()

    func isEqual(to viewModel: ImageViewModelProtocol) -> Bool
}

final class ImageViewModel: NSObject {
    private var url: URL

    private var imageTask: RetrieveImageTask?

    var targetSize: CGSize?

    var cornerRadius: CGFloat?

    init(url: URL) {
        self.url = url
    }
}

extension ImageViewModel: ImageViewModelProtocol {
    var image: UIImage? {

        let options: KingfisherOptionsInfo = [.callbackDispatchQueue(DispatchQueue.main),
                                              .processor(self)]

        if let currentImage = KingfisherManager.shared.cache
            .retrieveImageInMemoryCache(forKey: url.absoluteString, options: options) {
            return currentImage
        }

        if let currentImage = KingfisherManager.shared.cache
            .retrieveImageInDiskCache(forKey: url.absoluteString, options: options) {
            return currentImage
        }

        return nil
    }

    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void) {
        let imageResource = ImageResource(downloadURL: url)

        let options: KingfisherOptionsInfo = [.callbackDispatchQueue(DispatchQueue.main),
                                              .cacheSerializer(FormatIndicatedCacheSerializer.png),
                                              .processor(self)]

        imageTask?.cancel()

        imageTask = KingfisherManager.shared.retrieveImage(with: imageResource,
                                                           options: options,
                                                           progressBlock: nil) { [weak self] (image, error, _, _) in

                                                            if error?.code != NSURLErrorCancelled {
                                                                self?.imageTask = nil
                                                            }

                                                            completionBlock(image, error)
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

    func process(item: ImageProcessItem, options: KingfisherOptionsInfo) -> Image? {
        var resultItem = item
        let scaleFactor = UIScreen.main.scale

        if let size = targetSize {
            let resizeProcessor = ResizingImageProcessor(referenceSize: size, mode: .aspectFill)

            guard let resizedImage = resizeProcessor.process(item: item, options: [.scaleFactor(scaleFactor)]) else {
                return nil
            }

            let cropProcessor = CroppingImageProcessor(size: size, anchor: CGPoint(x: 0.5, y: 0.5))

            guard let cropedImage = cropProcessor.process(item: .image(resizedImage),
                                                          options: [.scaleFactor(scaleFactor)]) else {
                return nil
            }

            resultItem = .image(cropedImage)
        }

        if let radius = cornerRadius {
            let cornerProccessor = RoundCornerImageProcessor(cornerRadius: radius,
                                                             targetSize: nil,
                                                             roundingCorners: [.topLeft, .topRight],
                                                             backgroundColor: nil)

            guard let roundedImage = cornerProccessor.process(item: resultItem,
                                                              options: [.scaleFactor(scaleFactor)]) else {
                return nil
            }

            resultItem = .image(roundedImage)
        }

        switch resultItem {
        case .image(let image):
            return image
        case .data(let data):
            return Image(data: data)
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
        var result = ""

        if let targetSize = targetSize {
            result += "\(ProcessorIdentifier.widthField)\(ProcessorIdentifier.separator)\(Int(targetSize.width))"
            result += "\(ProcessorIdentifier.heightField)\(ProcessorIdentifier.separator)\(Int(targetSize.height))"
        } else {
            result += "\(ProcessorIdentifier.widthField)\(ProcessorIdentifier.separator)"
            result += "\(ProcessorIdentifier.emptyField)"
            result += "\(ProcessorIdentifier.heightField)\(ProcessorIdentifier.separator)"
            result += "\(ProcessorIdentifier.emptyField)"
        }

        result += ProcessorIdentifier.separator

        if let cornerRadius = cornerRadius {
            result += "\(ProcessorIdentifier.cornerRadiusField)\(ProcessorIdentifier.separator)\(Int(cornerRadius))"
        } else {
            result += "\(ProcessorIdentifier.cornerRadiusField)\(ProcessorIdentifier.separator)"
            result += "\(ProcessorIdentifier.emptyField)"
        }

        return result
    }
}
