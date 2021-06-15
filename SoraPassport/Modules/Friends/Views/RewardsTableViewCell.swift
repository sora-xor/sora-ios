import UIKit
import Then
import Anchorage

final class RewardsTableViewCell: UITableViewCell, Reusable {

    // MARK: - Outlets
    private var iconImageView: UIImageView = {
        UIImageView(image: nil).then {
            $0.widthAnchor == 32
            $0.heightAnchor == 32
            $0.contentMode = .center

            $0.layer.shadowRadius = 2
            $0.layer.shadowOpacity = 1
            $0.layer.shadowOffset = CGSize(width: 0, height: 1)
            $0.layer.shadowColor = UIColor(white: 0.3, alpha: 0.35).cgColor
        }
    }()

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph3)
            $0.textColor = R.color.baseContentPrimary()
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            $0.lineBreakMode = .byTruncatingMiddle
        }
    }()

    private var noteLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph4)
            $0.textColor = R.color.baseContentQuaternary()
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private var amountLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph2, isBold: true)
            $0.textColor = R.color.statusSuccess()
            $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            $0.textAlignment = .right
        }
    }()

    private var dateLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph4)
            $0.textColor = R.color.baseContentQuaternary()
            $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            $0.textAlignment = .right
        }
    }()

    private(set) var viewModel: RewardsViewModelProtocol?

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    func bind(viewModel: RewardsViewModelProtocol, styled: Bool = true) {
        self.viewModel = viewModel

        iconImageView.image = viewModel.icon

        if styled {
            titleLabel.attributedText = viewModel.title.styled(.paragraph3, lineBreakMode: .byTruncatingMiddle)
            noteLabel.attributedText = viewModel.note.styled(.paragraph4)
            amountLabel.attributedText = viewModel.amount.styled(.paragraph2)
            dateLabel.attributedText = viewModel.date.styled(.paragraph4)
        } else {
            titleLabel.text = viewModel.title
            noteLabel.text = viewModel.note
            amountLabel.text = viewModel.amount
            dateLabel.text = viewModel.date
        }
    }
}

private extension RewardsTableViewCell {

    func configure() {
        createContentStackView().do {
            addSubview($0)
            let insets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            $0.edgeAnchors == edgeAnchors + insets
        }
    }

    func createContentStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            // icon
            iconImageView,

            // labels
            UIStackView(arrangedSubviews: [
                // top labels
                UIStackView(arrangedSubviews: [
                    titleLabel.wrapped(height: 20),
                    amountLabel.wrapped(height: 20)
                ]).then {
                    $0.axis = .horizontal
                    $0.alignment = .firstBaseline
                    $0.spacing = 8
                },
                // bottom labels
                UIStackView(arrangedSubviews: [
                    noteLabel.wrapped(height: 16),
                    dateLabel.wrapped(height: 16)
                ]).then {
                    $0.axis = .horizontal
                    $0.alignment = .firstBaseline
                    $0.spacing = 8
                }
            ]).then {
                $0.axis = .vertical
                $0.spacing = 0
            }
        ]).then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.spacing = 8
        }
    }
}
