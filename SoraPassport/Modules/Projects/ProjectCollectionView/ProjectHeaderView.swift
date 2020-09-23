/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

final class ProjectHeaderView: UICollectionReusableView, Localizable {
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var votesButton: RoundedButton!
    @IBOutlet private(set) var helpButton: RoundedButton!
    @IBOutlet private(set) var segmentedControl: PlainSegmentedControl!

    override func awakeFromNib() {
        super.awakeFromNib()

        setupLocalization()
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations

        titleLabel.text = R.string.localizable.tabbarVotingTitle(preferredLanguages: languages)
    }

    func applyLocalization() {
        setupLocalization()

        if superview != nil {
            setNeedsLayout()
        }
    }
}
