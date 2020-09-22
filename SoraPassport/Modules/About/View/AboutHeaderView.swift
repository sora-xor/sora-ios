/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class AboutHeaderView: UIView {
    @IBOutlet private var titleLabel: UILabel!

    func bind(title: String) {
        titleLabel.text = title
    }
}
