/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol LayoutFlexible {
    var itemWidth: CGFloat { get }
    var contentInsets: UIEdgeInsets { get }
}

extension LayoutFlexible {
    var drawingBoundingSize: CGSize {
        return CGSize(width: itemWidth - contentInsets.left - contentInsets.right,
                      height: CGFloat.greatestFiniteMagnitude)
    }
}
