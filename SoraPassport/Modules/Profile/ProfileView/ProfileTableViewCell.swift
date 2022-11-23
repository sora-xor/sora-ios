import UIKit
import Then
import Anchorage

final class ProfileTableViewCell: UITableViewCell, Reusable {

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
        }
    }()

    private var iconImageView: UIImageView = {
        UIImageView(image: nil).then {
            $0.widthAnchor == 24
            $0.contentMode = .center
            $0.tintColor = R.color.baseContentQuaternary()
        }
    }()

    private var accessoryTitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph2, isBold: false)
            $0.textColor = R.color.neumorphism.swiperTextGrey()
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.widthAnchor <= 86
            $0.lineBreakMode = .byTruncatingMiddle
            $0.isHidden = true
        }
    }()

    private var arrowImageView: UIImageView = {
        UIImageView(
            image: R.image.circleChevronRight()?
                .withRenderingMode(.alwaysTemplate)).then {
            $0.widthAnchor == 16
            $0.contentMode = .center
            $0.tintColor = R.color.baseContentQuaternary()
        }
    }()

    private lazy var switchButton: UISwitch = {
        UISwitch().then {
            $0.isOn = false
            $0.isHidden = true
            $0.onTintColor = R.color.statusSuccess()
            $0.tintColor = R.color.baseContentQuaternary()
            $0.backgroundColor = R.color.baseContentQuaternary()
            $0.layer.cornerRadius = $0.frame.height / 2
            $0.addTarget(
                self, action: #selector(switchAction(_:)),
                for: .valueChanged
            )
        }
    }()

    private var separatorView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.neumorphism.separator()
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
        }
    }()

    private(set) var viewModel: ProfileOptionViewModelProtocol?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? ProfileOptionViewModelProtocol else { return }

        titleLabel.text = viewModel.title
        iconImageView.image = viewModel.iconImage?
            .withRenderingMode(.alwaysTemplate)

        if let accessoryContent = viewModel.accessoryContent {
            accessoryTitleLabel.text = accessoryContent.title
            accessoryTitleLabel.isHidden = false
        } else {
            accessoryTitleLabel.isHidden = true
        }

        if let switchContent = viewModel.switchContent {
            accessoryTitleLabel.isHidden = true
            arrowImageView.isHidden = true
            switchButton.isHidden = false
            switchButton.isOn = switchContent.isOn
            contentView.isUserInteractionEnabled = false
        } else {
            arrowImageView.isHidden = false
            switchButton.isHidden = true
            contentView.isUserInteractionEnabled = true
        }
    }
}

private extension ProfileTableViewCell {

    func configure() {
        backgroundColor = R.color.baseBackground()
        createContentStackView().do {
            addSubview($0)
            let insets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            $0.edgeAnchors == edgeAnchors + insets
            $0.heightAnchor == 56
        }

        separatorView.do {
            addSubview($0)
            $0.centerXAnchor == centerXAnchor
            $0.bottomAnchor == bottomAnchor
        }
    }

    func createContentStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            iconImageView,
            titleLabel,
            accessoryTitleLabel,
            switchButton,
            arrowImageView
        ]).then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.spacing = 16
        }
    }

    @objc func switchAction(_ sender: UISwitch) {
        viewModel?.switchContent?.action?(sender.isOn)
    }
}
