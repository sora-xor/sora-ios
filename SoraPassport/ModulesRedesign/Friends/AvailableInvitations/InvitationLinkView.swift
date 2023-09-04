import UIKit
import Anchorage
import SoraUI
import SoraUIKit

protocol InvitationLinkViewDelegate: AnyObject {
    func shareButtonTapped(with text: String)
}

final class InvitationLinkView: SoramitsuView {

    weak var delegate: InvitationLinkViewDelegate?

    private lazy var shareButton: ImageButton = {
        ImageButton(size: CGSize(width: 24, height: 24)).then {
            $0.sora.image = R.image.shareIcon()
            $0.sora.tintColor = .fgSecondary
            $0.sora.backgroundColor = .custom(uiColor: .clear)
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.buttonTapped()
            }
        }
    }()

    let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.text = R.string.localizable.referralYourInvitationLinkTitle(preferredLanguages: .currentLocale)
            $0.sora.textColor = .fgSecondary
            $0.sora.alignment = .right
            $0.sora.font = FontType.textXS
        }
    }()

    let linkLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.alignment = .left
            $0.sora.font = FontType.textM
        }
    }()

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func buttonTapped() {
        delegate?.shareButtonTapped(with: linkLabel.sora.text ?? "")
        UIPasteboard.general.string = linkLabel.sora.text
    }
}

private extension InvitationLinkView {
    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.borderColor = .bgSurfaceVariant
        sora.borderWidth = 1.0
        sora.shadow = .small
        sora.cornerRadius = .circle

        addSubview(shareButton)
        addSubview(titleLabel)
        addSubview(linkLabel)

        shareButton.do {
            $0.trailingAnchor == trailingAnchor - 8
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
