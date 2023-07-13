import UIKit
import SoraUIKit
import Then
import Anchorage

protocol ButtonCellDelegate {
    func buttonTapped()
}

final class ButtonCell: UITableViewCell {

    private var delegate: ButtonCellDelegate?

    // MARK: - Outlets
    private lazy var button: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.backgroundColor = .additionalPolkaswap
            $0.sora.cornerRadius = .circle
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.buttonTapped()
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

    func buttonTapped() {
        delegate?.buttonTapped()
    }
}

extension ButtonCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let model = viewModel as? ButtonViewModelProtocol else { return }
        button.sora.title = model.title
        button.sora.isEnabled = model.isEnabled
        self.delegate = model.delegate
    }
}

private extension ButtonCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(button)

        button.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.heightAnchor == 56
            $0.bottomAnchor == contentView.bottomAnchor
        }
    }
}
