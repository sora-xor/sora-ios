import UIKit
import Then
import Anchorage

final class AccountTableViewCell: UITableViewCell, Reusable {

    // MARK: - Outlets
    private var iconImageView: UIImageView = {
        UIImageView(image: nil).then {
            $0.widthAnchor == 40
            $0.heightAnchor == 40
        }
    }()
    
    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.lineBreakMode = .byTruncatingMiddle
        }
    }()
    
    private lazy var stackView: UIStackView = {
        UIStackView(arrangedSubviews: [
            iconImageView,
            titleLabel
        ]).then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.spacing = 16
        }
    }()
    
    private var checkmarkImageView: UIImageView = {
        UIImageView(
            image: R.image.profile.checkmark()).then {
            $0.widthAnchor == 18
        }
    }()
    
    private var separatorView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.neumorphism.separator()
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
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

    func bind(viewModel: AccountViewModelProtocol, styled: Bool = true) {
        self.titleLabel.text = viewModel.title
        self.checkmarkImageView.isHidden = !viewModel.isSelected
        self.iconImageView.image = viewModel.iconImage
    }
}

private extension AccountTableViewCell {

    func configure() {
        backgroundColor = R.color.baseBackground()

        addSubview(stackView)
        addSubview(separatorView)
        addSubview(checkmarkImageView)

        stackView.do {
            $0.leadingAnchor == leadingAnchor + 16
            $0.trailingAnchor == checkmarkImageView.leadingAnchor - 110
            $0.centerYAnchor == centerYAnchor
        }

        separatorView.do {
            $0.centerXAnchor == centerXAnchor
            $0.bottomAnchor == bottomAnchor
        }

        checkmarkImageView.do {
            $0.trailingAnchor == trailingAnchor - 16
            $0.centerYAnchor == centerYAnchor
        }
    }
}
