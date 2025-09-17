/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import SoraUI

class PlainSegmentedControlTests: XCTestCase {
    func testSelectedIndexIsNotChangedIfNewTitlesCountTheSame() {
        // given

        let titles = ["Title1", "Title2", "Title3"]
        let selectedIndex = titles.count - 1

        let frame = CGRect(origin: .zero, size: CGSize(width: 320.0, height: 100.0))
        let segmentedControl = PlainSegmentedControl(frame: frame)
        segmentedControl.titles = titles

        segmentedControl.selectedSegmentIndex = selectedIndex

        XCTAssertEqual(segmentedControl.selectedSegmentIndex, selectedIndex)

        // when

        segmentedControl.titles = titles.reversed()

        // then

        XCTAssertEqual(segmentedControl.selectedSegmentIndex, selectedIndex)
    }
}
