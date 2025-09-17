/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import SoraUI

final class SegmentedControlViewController: UIViewController {
    @IBOutlet private var segmentedControl1: PlainSegmentedControl!
    @IBOutlet private var segmentedControl2: PlainSegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()

        segmentedControl1.titles = ["All", "Voted", "Favorite"]

        segmentedControl2.layoutStrategy = HorizontalFlexibleLayoutStrategy(margin: 20.0)
        segmentedControl2.titles = ["All", "Voted", "Favorite", "Complete"]
    }

    @IBAction private func actionSegmentedControlChanged(_ sender: PlainSegmentedControl) {
        if sender === segmentedControl1 {
            print("Current selection index in first segmented control: \(sender.selectedSegmentIndex)")
        } else {
            print("Current selection index in second segmented control: \(sender.selectedSegmentIndex)")
        }
    }
}
