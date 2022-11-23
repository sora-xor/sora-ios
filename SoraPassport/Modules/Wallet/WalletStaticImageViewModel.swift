import Foundation
import CommonWallet

final class WalletStaticImageViewModel: WalletImageViewModelProtocol {
    let staticImage: UIImage

    init(staticImage: UIImage) {
        self.staticImage = staticImage
    }

    var image: UIImage? { staticImage }

    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void) {
        completionBlock(image, nil)
    }

    func cancel() {}
}

final class WalletSvgImageViewModel: WalletImageViewModelProtocol {
    var image: UIImage?

    let svgString: String

    init(svgString: String) {
        self.svgString = svgString
    }

    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: self.svgString)
            DispatchQueue.main.async {
                completionBlock(icon, nil)
            }
        }
    }

    func cancel() {

    }
}
