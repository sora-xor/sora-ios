/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

extension String {
    func drawingSize(for size: CGSize, font: UIFont, options: NSStringDrawingOptions) -> CGSize {
        let attributes = [NSAttributedString.Key.font: font]
        return (self as NSString).boundingRect(with: size,
                                               options: options,
                                               attributes: attributes,
                                               context: nil).size
    }
}
