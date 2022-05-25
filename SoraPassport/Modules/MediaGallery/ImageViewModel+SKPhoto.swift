import Foundation
import SKPhotoBrowser

private struct ImageGalleryConstants {
    static var indexKey: String = "co.jp.sora.galery.index"
    static var contentModeKey: String = "co.jp.sora.galery.mode"
}

extension ImageViewModel: SKPhotoProtocol {
    var index: Int {
        get {
            let optionalIndex = objc_getAssociatedObject(self, &ImageGalleryConstants.indexKey) as? Int
            return optionalIndex ?? 0
        }

        set {
            objc_setAssociatedObject(self,
                                     &ImageGalleryConstants.indexKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var underlyingImage: UIImage! {
        return image ?? nil
    }

    var caption: String? {
        return nil
    }

    var contentMode: UIView.ContentMode {
        get {
            let optionalContentMode = objc_getAssociatedObject(self, &ImageGalleryConstants.contentModeKey)
                as? UIView.ContentMode

            return optionalContentMode ?? .scaleAspectFit
        }

        set {
            objc_setAssociatedObject(self,
                                     &ImageGalleryConstants.contentModeKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func loadUnderlyingImageAndNotify() {
        guard image == nil else {
            notifyLoadingDidEnd()
            return
        }

        loadImage { (_, _) in
            self.loadUnderlyingImageAndNotify()
        }
    }

    func checkCache() {}

    private func notifyLoadingDidEnd() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION),
                                        object: self)
    }
}
