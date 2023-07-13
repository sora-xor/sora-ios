import UIKit
import SoraUIKit
import Then
import Anchorage

final class TextCell: UITableViewCell {

    // MARK: - Outlets
    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.numberOfLines = 0
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

extension TextCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? TextViewModel else { return }
        titleLabel.sora.text = viewModel.title
        titleLabel.sora.font = viewModel.font ?? titleLabel.sora.font
        titleLabel.sora.textColor = viewModel.textColor ?? titleLabel.sora.textColor
        titleLabel.sora.alignment = viewModel.textAligment
    }
}

private extension TextCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(titleLabel)

        titleLabel.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.centerYAnchor == contentView.centerYAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 24
        }
    }
}
