/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraUI

protocol VotesButtonFactoryProtocol {
    static func createBarVotesButton() -> RoundedButton
}

final class VotesButtonFactory: VotesButtonFactoryProtocol {
    static func createBarVotesButton() -> RoundedButton {
        let votesButton = RoundedButton()
        votesButton.roundedBackgroundView?.shadowOpacity = 0.0
        votesButton.roundedBackgroundView?.fillColor = .clear
        votesButton.roundedBackgroundView?.highlightedFillColor = .clear
        votesButton.changesContentOpacityWhenHighlighted = true
        votesButton.imageWithTitleView?.iconImage = R.image.votesIcon()
        votesButton.imageWithTitleView?.titleColor = .barVotes
        votesButton.imageWithTitleView?.titleFont = .barVotes
        votesButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 10

        return votesButton
    }
}
