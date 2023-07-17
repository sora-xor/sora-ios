import UIKit
import Then
import Anchorage
import SoraUI
import SoraUIKit

protocol ReferrerCellDelegate: AnyObject {
    func enterLinkButtonTapped()
}

final class ReferrerCell: SoramitsuTableViewCell {

    private var delegate: ReferrerCellDelegate?

    // MARK: - Outlets
    private var containerView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.sora.distribution = .fill
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.sora.cornerMask = .all
            $0.sora.shadow = .small
            $0.spacing = 16
            $0.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            $0.isLayoutMarginsRelativeArrangement = true
        }
    }()

    private lazy var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.text = R.string.localizable.referralYourReferrer(preferredLanguages: .currentLocale)
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.headline2
        }
    }()

    private lazy var addressLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.paragraphXS
            $0.sora.lineBreakMode = .byTruncatingMiddle
        }
    }()

    private lazy var enterLinkButton: SoramitsuButton = {
        SoramitsuButton().then {
            let title = SoramitsuTextItem(text: R.string.localizable.referralEnterLinkTitle(preferredLanguages: .currentLocale) ,
                                          fontData: FontType.buttonM ,
                                          textColor: .accentPrimary ,
                                          alignment: .center)
            
            $0.sora.horizontalOffset = 0
            $0.sora.cornerRadius = .circle
            $0.sora.backgroundColor = .accentPrimaryContainer
            $0.sora.attributedText = title
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.enterLinkButtonTapped()
            }
        }
    }()

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    @objc
    func enterLinkButtonTapped() {
        delegate?.enterLinkButtonTapped()
    }
}

extension ReferrerCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? ReferrerViewModel else { return }
        addressLabel.sora.text = viewModel.address
        addressLabel.sora.isHidden = viewModel.address.isEmpty
        enterLinkButton.sora.isHidden = !viewModel.address.isEmpty
        delegate = viewModel.delegate
    }
}

private extension ReferrerCell {

    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addArrangedSubviews([
            titleLabel,
            addressLabel,
            enterLinkButton
        ])
        
        containerView.do {
            $0.topAnchor == contentView.topAnchor + 6
            $0.bottomAnchor == contentView.bottomAnchor - 10
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }
        
        enterLinkButton.do {
            $0.heightAnchor == 56
        }
    }
}
