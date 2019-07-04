/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

struct HelpItemLayoutMetadata: Withable {
    var itemWidth: CGFloat = 375.0
    var contentInset = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
    var titleColor: UIColor = UIColor.black
    var titleFont: UIFont = UIFont.systemFont(ofSize: UIFont.labelFontSize)
    var detailsTopSpacing: CGFloat = 15.0
    var detailsTitleColor: UIColor = UIColor.black
    var detailsFont: UIFont = UIFont.systemFont(ofSize: UIFont.labelFontSize)
    var separatorWidth: CGFloat = 1.0
    var separatorColor: UIColor = UIColor.black
    var containsSeparator: Bool = false
    var separatorBottomMargin: CGFloat = 0.0
    var drawingOptions: NSStringDrawingOptions = .usesLineFragmentOrigin
}
