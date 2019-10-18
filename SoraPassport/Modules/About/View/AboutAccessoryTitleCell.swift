/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class AboutAccessoryTitleCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var accessoryLabel: UILabel!

    func bind(title: String, subtitle: String) {
        titleLabel.text = title
        accessoryLabel.text =  subtitle
    }
}
