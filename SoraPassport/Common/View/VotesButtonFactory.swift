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
        votesButton.imageWithTitleView?.titleColor = R.color.baseContentTertiary()!
        votesButton.imageWithTitleView?.titleFont = UIFont.styled(for: .paragraph3)
        votesButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 10

        return votesButton
    }
}
