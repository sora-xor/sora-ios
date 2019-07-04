/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class MediaGalleryCollectionViewCell: AnimatableCollectionView {
    @IBOutlet private var coverImageView: UIImageView!

    lazy var appearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)

    private(set) var viewModel: ProjectImageViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.cancel()
        coverImageView.image = nil
    }

    func bind(model: ProjectImageViewModelProtocol) {
        viewModel = model
        updateCoverImage()
    }

    private func updateCoverImage() {
        if let image = viewModel?.image {
            coverImageView.image = image
            return
        }

        viewModel?.loadImage { [weak self] (image, error) in
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
}
