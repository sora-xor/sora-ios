/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraUI

final class ProjectCompactBar: ShadowShapeView {
    @IBOutlet private(set) var segmentedControl: PlainSegmentedControl!
    @IBOutlet private(set) var votesButton: RoundedButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        updateSegmentedControlLayout()
    }

    var segmentedControlItemMargin: CGFloat = 20.0 {
        didSet {
            updateSegmentedControlLayout()
        }
    }

    private func updateSegmentedControlLayout() {
        segmentedControl.layoutStrategy = HorizontalFlexibleLayoutStrategy(margin: segmentedControlItemMargin)
    }
}
