import UIKit
import Anchorage
import SoraUI

protocol InvitationLinkViewDelegate: AnyObject {
    func shareButtonTapped(with text: String)
}

final class InvitationLinkView: UIView {

    weak var delegate: InvitationLinkViewDelegate?

    private let shareButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.layer.cornerRadius = 20
            $0.image = R.image.shareIcon()
            $0.color = R.color.neumorphism.shareButtonGrey()!
            $0.tintColor = .black
            $0.topShadowColor = .clear
            $0.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        }
    }()

    let titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph3)
            $0.textColor = R.color.neumorphism.borderBase()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.textAlignment = .right
            $0.text = R.string.localizable.referralYourInvitationLinkTitle(preferredLanguages: .currentLocale)
        }
    }()

    let linkLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.textAlignment = .left
        }
    }()

    lazy var gradient: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.type = .radial
        gradient.colors = [
            R.color.neumorphism.shadowLightGray()!.cgColor,
            R.color.neumorphism.shadowSuperLightGray()!.cgColor
        ]
        gradient.cornerRadius = 24
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.locations = [ 0.5, 1 ]
        return gradient
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let endX = 1 +  frame.size.height / frame.size.width
        gradient.endPoint = CGPoint(x: endX, y: 1)

        gradient.frame = bounds
    }

    @objc
    func buttonTapped() {
        delegate?.shareButtonTapped(with: linkLabel.text ?? "")
        UIPasteboard.general.string = linkLabel.text
    }
}

private extension InvitationLinkView {
    func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = R.color.neumorphism.buttonLightGrey()
        layer.cornerRadius = 24

        layer.addSublayer(gradient)
        addSubview(shareButton)
        addSubview(titleLabel)
        addSubview(linkLabel)

        shareButton.do {
            $0.trailingAnchor == trailingAnchor - 8
            $0.heightAnchor == 40
            $0.widthAnchor == 40
            $0.centerYAnchor == centerYAnchor
        }

        titleLabel.do {
            $0.topAnchor == topAnchor + 10
            $0.leadingAnchor == leadingAnchor + 16
            $0.heightAnchor == 16
        }

        linkLabel.do {
            $0.topAnchor == titleLabel.bottomAnchor + 4
            $0.leadingAnchor == leadingAnchor + 16
            $0.trailingAnchor == shareButton.leadingAnchor - 14
            $0.bottomAnchor == bottomAnchor - 10
            $0.heightAnchor == 16
        }
    }
}
