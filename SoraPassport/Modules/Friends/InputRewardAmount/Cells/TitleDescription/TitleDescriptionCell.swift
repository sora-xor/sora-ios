import UIKit
import Then
import Anchorage

final class TitleDescriptionCell: UITableViewCell {

    // MARK: - Outlets
    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4)
            $0.textColor = R.color.baseContentPrimary()
            $0.numberOfLines = 0
        }
    }()
    
    private var descriptionLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.numberOfLines = 0
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
}

extension TitleDescriptionCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? TitleDescriptionViewModel else { return }
        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.descriptionText
    }
}

private extension TitleDescriptionCell {

    func configure() {
        backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)

        titleLabel.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 24
        }

        descriptionLabel.do {
            $0.topAnchor == titleLabel.bottomAnchor + 16
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 24
            $0.bottomAnchor == contentView.bottomAnchor
        }
    }
}
