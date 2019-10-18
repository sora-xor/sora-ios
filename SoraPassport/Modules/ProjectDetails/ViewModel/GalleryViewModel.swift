/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum GalleryViewModel {
    case image(viewModel: ImageViewModelProtocol)
    case video(viewModel: VideoViewModelProtocol)
}
