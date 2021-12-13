import UIKit
import SoraUI

final class MediaGalleryVideoCollectionViewCell: AnimatableCollectionView {
    @IBOutlet private var coverImageView: UIImageView!
    @IBOutlet private var durationLabel: RoundedButton!

    lazy var appearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)

    private(set) var viewModel: VideoViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.preview?.cancel()
        coverImageView.image = nil
    }

    func bind(model: VideoViewModelProtocol) {
        viewModel = model
        updateCoverImage()
        updateDuration()
    }

    private func updateCoverImage() {
        if let image = viewModel?.preview?.image {
            coverImageView.image = image
            return
        }

        guard let preview = viewModel?.preview else {
            return
        }

        preview.loadImage { [weak self] (image, error) in
            guard error == nil else {
                return
            }

            guard let strongSelf = self else {
                return
            }

            strongSelf.coverImageView.image = image

            strongSelf.appearanceAnimator.animate(view: strongSelf.coverImageView,
                                                  completionBlock: nil)
        }
    }

    private func updateDuration() {
        durationLabel.imageWithTitleView?.title = viewModel?.duration
        durationLabel.invalidateLayout()
    }
}
