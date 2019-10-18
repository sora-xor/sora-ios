import Foundation

protocol VideoViewModelProtocol {
    var preview: ImageViewModelProtocol? { get }
    var duration: String { get }
}

final class VideoViewModel: VideoViewModelProtocol {
    var preview: ImageViewModelProtocol?
    var duration: String

    init(preview: ImageViewModelProtocol?, duration: String) {
        self.preview = preview
        self.duration = duration
    }
}
