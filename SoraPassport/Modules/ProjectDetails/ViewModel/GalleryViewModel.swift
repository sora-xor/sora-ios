import Foundation

enum GalleryViewModel: Equatable {
    case image(viewModel: ImageViewModelProtocol)
    case video(viewModel: VideoViewModelProtocol)

    var viewModel: Any {
        switch self {
        case .image(let viewModel):
            return viewModel
        case .video(let viewModel):
            return viewModel
        }
    }

    static func == (lhs: GalleryViewModel, rhs: GalleryViewModel) -> Bool {
        let viewModel = lhs.viewModel
        let otherViewModel = rhs.viewModel

        if let imageViewModel = viewModel as? ImageViewModelProtocol,
            let otherImageViewModel = otherViewModel as? ImageViewModelProtocol {
            return imageViewModel.isEqual(to: otherImageViewModel)
        }

        if let videoViewModel = viewModel as? VideoViewModelProtocol,
            let otherVideoViewModelProtocol = otherViewModel as? VideoViewModelProtocol {
            return videoViewModel.isEqual(to: otherVideoViewModelProtocol)
        }

        return false
    }
}
