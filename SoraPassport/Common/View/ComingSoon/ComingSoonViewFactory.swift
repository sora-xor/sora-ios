import UIKit
import Then
import Anchorage

final class ComingSoonViewFactory {

    static func comingSoonView() -> (container: UIView, label: UILabel) {

        let label = UILabel().then {
            $0.textColor = R.color.baseContentTertiary()
            $0.font = UIFont.styled(for: .uppercase3, isBold: true)
        }

        let container = UIView().then {
            $0.backgroundColor = .clear
            $0.addSubview(label)
        }

        container.heightAnchor == 14
        label.edgeAnchors == container.edgeAnchors

        return (container, label)
    }

    static func descriptionView() -> (container: UIView, label: UILabel) {

        let label = UILabel().then {
            $0.numberOfLines = 0
            $0.textColor = R.color.baseContentTertiary()
            $0.font = UIFont.styled(for: .paragraph1)
        }

        let container = UIView().then {
            $0.backgroundColor = .clear
            $0.addSubview(label)
        }

        let topConstraint = (label.edgeAnchors == container.edgeAnchors).top
        topConstraint.constant += 12

        return (container, label)
    }
}
