/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol PosterViewFactoryProtocol {
    static func createView(from contentInsets: UIEdgeInsets,
                           preferredWidth: CGFloat) -> PosterView?

    static func createLayoutMetadata(from contentInsets: UIEdgeInsets,
                                     preferredWidth: CGFloat) -> PosterLayoutMetadata
}
