/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class ProfileSectionHeader: UIView {
    
    @IBOutlet private var titleLabel: UILabel!
    
    func set(title: String) {
        titleLabel.text = title
        titleLabel.font = UIFont.styled(for: .paragraph1)
        titleLabel.textColor = R.color.baseContentPrimary()
    }
    
}
