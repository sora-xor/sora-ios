/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

class ExplainingCommandView: UIView {

    @IBOutlet var headerIcon: UIImageView!
    @IBOutlet var externalIcon: UIImageView!
    @IBOutlet var soraIcon: UIImageView!
    @IBOutlet var soraTitleLabel: UILabel!
    @IBOutlet var soraValueLabel: UILabel!
    @IBOutlet var headerLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.headerIcon.image = R.image.iconAlert()
        self.soraIcon.image = R.image.linkInfo()
        self.externalIcon.image = R.image.iconExternalLink()
    }
}
