import Foundation
import SoraUIKit
import Anchorage

final class Card: SoramitsuView {

    private let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.headline4
            $0.sora.textColor = .fgSecondary
            $0.numberOfLines = 1
        }
    }()

    private let bottomLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.paragraphXS
            $0.sora.textColor = .fgSecondary
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
        }
    }()

    private let stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 0
            $0.sora.distribution = .fill
        }
    }()

    public var headerText: String = "" {
        didSet {
            titleLabel.sora.text = headerText
        }
    }

    public var footerText: String = "" {
        didSet {
            bottomLabel.sora.text = footerText
        }
    }

    public var stackContents: [UIView] = [] {
        didSet {
            stackView.removeArrangedSubviews()
            stackView.addArrangedSubviews(stackContents)
        }
    }

    init() {
        super.init(frame: .zero)
        sora.backgroundColor = .bgSurface
        layer.cornerRadius = 32
        layer.masksToBounds = true
        sora.shadow = .default
        layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        addSubviews(titleLabel, stackView, bottomLabel)

        titleLabel.do {
            $0.topAnchor == topAnchor + 24
            $0.horizontalAnchors == horizontalAnchors + 24
            $0.bottomAnchor == stackView.topAnchor - 8
        }
        stackView.do {
            $0.horizontalAnchors == horizontalAnchors
        }
        bottomLabel.do {
            $0.topAnchor == stackView.bottomAnchor + 8
            $0.horizontalAnchors == horizontalAnchors + 24
            $0.bottomAnchor == bottomAnchor - 24
        }
    }
}
