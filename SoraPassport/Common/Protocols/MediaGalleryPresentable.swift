/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SKPhotoBrowser

protocol MediaGalleryPresentable {
    func showGallery(from view: ControllerBackedProtocol?,
                     for urls: [URL],
                     with selectedIndex: Int,
                     animateFrom animatingView: UIView?)
}

extension MediaGalleryPresentable {
    func showGallery(from view: ControllerBackedProtocol?,
                     for urls: [URL],
                     with selectedIndex: Int,
                     animateFrom animatingView: UIView?) {
        guard let presenter = view?.controller else {
            return
        }

        let photos = urls.map { ProjectImageViewModel(url: $0) }

        let gallery: SKPhotoBrowser!

        if let image = photos[selectedIndex].image, let animatingView = animatingView {
            gallery = SKPhotoBrowser(originImage: image,
                                     photos: photos,
                                     animatedFromView: animatingView)
            gallery.initializePageIndex(selectedIndex)
        } else {
            gallery = SKPhotoBrowser(photos: photos, initialPageIndex: selectedIndex)
        }

        gallery.modalTransitionStyle = .crossDissolve

        presenter.present(gallery,
                          animated: true,
                          completion: nil)
    }
}
