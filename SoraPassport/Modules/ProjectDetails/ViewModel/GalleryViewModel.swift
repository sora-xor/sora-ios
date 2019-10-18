import Foundation

enum GalleryViewModel {
    case image(viewModel: ImageViewModelProtocol)
    case video(viewModel: VideoViewModelProtocol)
}
