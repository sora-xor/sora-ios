/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class ProjectHeaderView: UICollectionReusableView {
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var votesButton: RoundedButton!
    @IBOutlet private(set) var helpButton: RoundedButton!
    @IBOutlet private(set) var segmentedControl: PlainSegmentedControl!
}
