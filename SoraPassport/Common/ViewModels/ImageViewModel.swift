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

//TODO: disk cache?
//        if let currentImage = KingfisherManager.shared.cache
//            .retrieveImageInDiskCache(forKey: url.absoluteString, options: options, completionHandler: { result in
//                switch result {
//                case .success(let image):
//                return image
//                default:
//                    print("no image")
//                }
//            })



        return nil
    }

    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void) {
        let imageResource = ImageResource(downloadURL: url)

        let options: KingfisherOptionsInfo = [.callbackQueue(.mainCurrentOrAsync),
                                              .cacheSerializer(FormatIndicatedCacheSerializer.png),
                                              .processor(self)]

        imageTask?.cancel()

        imageTask = KingfisherManager.shared.retrieveImage(with: imageResource,
                                                           options: options,
                                                           progressBlock: nil) { [weak self] result in
            switch result {
            case .success(let value):
                completionBlock(value.image, nil)
            case .failure(let error):
                //TODO: cancelling error?
//                if error != KingfisherError.requestError(reason: .taskCancelled(task: self?.imageTask, token: self?.imageTask?.cancelToken)) {
//                    self?.imageTask = nil
//                }
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
        let scaleFactor = UIScreen.main.scale

        if let size = targetSize {
            let resizeProcessor = ResizingImageProcessor(referenceSize: size, mode: .aspectFill)
//            let options: KingfisherParsedOptionsInfo = [.scaleFactor(scaleFactor)]

            guard let resizedImage = resizeProcessor.process(item: item, options: options) else {
                return nil
            }

            let cropProcessor = CroppingImageProcessor(size: size, anchor: CGPoint(x: 0.5, y: 0.5))

            guard let cropedImage = cropProcessor.process(item: .image(resizedImage),
                                                          options: options) else {
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
