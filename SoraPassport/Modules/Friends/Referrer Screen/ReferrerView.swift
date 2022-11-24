import Foundation
import UIKit
import SoraFoundation
import SoraUI
import Anchorage

final class ReferrerView: RoundedView {

    var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4).withSize(11.0)
            $0.textColor = R.color.neumorphism.text()
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    var descriptionLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.brandUltraBlack()
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()

    var referrersTitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph3)
            $0.textColor = R.color.neumorphism.textGray()
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()

    var referrersAddressLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.brandUltraBlack()
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.lineBreakMode = .byTruncatingMiddle
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        cornerRadius = 40.0
        shadowColor = R.color.neumorphism.base()!
        roundingCorners = [.topLeft, .topRight]

        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(referrersTitleLabel)
        addSubview(referrersAddressLabel)

        titleLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.topAnchor == topAnchor + 20
            $0.heightAnchor == 11
        }

        descriptionLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.topAnchor == titleLabel.bottomAnchor + 16
        }

        referrersTitleLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.topAnchor == descriptionLabel.bottomAnchor + 24
        }

        referrersAddressLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.topAnchor == referrersTitleLabel.bottomAnchor + 4
            $0.bottomAnchor == bottomAnchor - 52
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ReferrerView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
}
