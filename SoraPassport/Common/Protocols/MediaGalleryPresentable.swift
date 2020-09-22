import Foundation
import SKPhotoBrowser
import AVFoundation
import AVKit

protocol MediaGalleryPresentable {
    func showGallery(from view: ControllerBackedProtocol?,
                     for items: [MediaItemData],
                     with selectedIndex: Int,
                     animateFrom animatingView: UIView?)
}

extension MediaGalleryPresentable {
    func showGallery(from view: ControllerBackedProtocol?,
                     for items: [MediaItemData],
                     with selectedIndex: Int,
                     animateFrom animatingView: UIView?) {
        switch items[selectedIndex] {
        case .video(let item):
            showVideo(from: view, for: item.url)
        case .image(let item):
            let urls: [URL] = items.compactMap { media in
                switch media {
                case .image(let mediaItem):
                    return mediaItem.url
                case .video:
                    return nil
                }
            }

            if let adjustedIndex = urls.firstIndex(of: item.url) {
                showImageGallery(from: view,
                                 for: urls,
                                 with: adjustedIndex,
                                 animateFrom: animatingView)
            }
        }
    }

    private func showImageGallery(from view: ControllerBackedProtocol?,
                                  for urls: [URL],
                                  with selectedIndex: Int,
                                  animateFrom animatingView: UIView?) {
        guard let presenter = view?.controller else {
            return
        }

        let photos = urls.map { ImageViewModel(url: $0) }

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

    private func showVideo(from view: ControllerBackedProtocol?, for url: URL) {
        guard let presenter = view?.controller else {
            return
        }

        let player = AVPlayer(url: url)
        let playerController = AVPlayerViewController()
        playerController.player = player

        presenter.present(playerController, animated: true) { player.play() }
    }
}
