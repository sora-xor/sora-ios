/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension GalleryViewModel {
    static func from(media: MediaItemData) -> GalleryViewModel {
        switch media {
        case .image(let item):
            return .image(viewModel: ImageViewModel(url: item.url))
        case .video(let item):
            var preview: ImageViewModel?

            if let previewUrl = item.previewUrl {
                preview = ImageViewModel(url: previewUrl)
            }

            let duration = String.displayDuration(from: item.duration)
            return .video(viewModel: VideoViewModel(preview: preview, duration: duration))
        }
    }
}
