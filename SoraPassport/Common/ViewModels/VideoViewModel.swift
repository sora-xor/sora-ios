import Foundation

protocol VideoViewModelProtocol {
    var preview: ImageViewModelProtocol? { get }
    var duration: String { get }

    func isEqual(to viewModel: VideoViewModelProtocol) -> Bool
}

final class VideoViewModel: VideoViewModelProtocol {
    var preview: ImageViewModelProtocol?
    var duration: String

    init(preview: ImageViewModelProtocol?, duration: String) {
        self.preview = preview
        self.duration = duration
    }

    func isEqual(to viewModel: VideoViewModelProtocol) -> Bool {
        guard let currentPreview = preview, let otherPreview = viewModel.preview else {
            return (preview == nil && viewModel.preview == nil) && duration == viewModel.duration
        }

        return currentPreview.isEqual(to: otherPreview) && duration == viewModel.duration
    }
}
