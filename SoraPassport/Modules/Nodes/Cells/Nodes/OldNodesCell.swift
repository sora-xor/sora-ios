import UIKit
import Then
import Anchorage
import SoraUI

final class OldNodesCell: UITableViewCell {

    private var delegate: NodesCellDelegate?

    // MARK: - Outlets
    private var containerView: UIView = {
        RoundedView().then {
            $0.fillColor = R.color.neumorphism.backgroundLightGrey() ?? .white
            $0.cornerRadius = 24
            $0.roundingCorners = [ .topLeft, .topRight, .bottomLeft, .bottomRight ]
            $0.shadowRadius = 3
            $0.shadowOpacity = 0.3
            $0.shadowOffset = CGSize(width: 0, height: -1)
            $0.shadowColor = UIColor(white: 0, alpha: 0.3)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var stackView: UIStackView = {
        UIStackView().then {
            $0.axis = .vertical
            $0.spacing = 32
            $0.translatesAutoresizingMaskIntoConstraints = false
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

extension OldNodesCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? OldNodesViewModel else { return }

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        viewModel.nodesModels.forEach { node in
            let view = OldNodeView()
            view.updateView(model: node)
            view.onSelect = { node in
                viewModel.delegate?.onAction(.select(node: node))
            }
            view.onCopy = { node in
                viewModel.delegate?.onAction(.copy(node: node))
            }
            view.onEdit = { node in
                viewModel.delegate?.onAction(.edit(node: node))
            }
            view.onRemove = { node in
                viewModel.delegate?.onAction(.remove(node: node))
            }
            stackView.addArrangedSubview(view)
        }

        delegate = viewModel.delegate
    }
}

private extension OldNodesCell {

    func configure() {
        backgroundColor = R.color.baseBackground()
        selectionStyle = .none

        contentView.addSubview(containerView)
        contentView.addSubview(stackView)

        containerView.do {
            $0.topAnchor == stackView.topAnchor - 24
            $0.bottomAnchor == stackView.bottomAnchor + 24
            $0.centerXAnchor == stackView.centerXAnchor
            $0.leadingAnchor == stackView.leadingAnchor - 16
        }

        stackView.do {
            $0.topAnchor == contentView.topAnchor + 30
            $0.leadingAnchor == contentView.leadingAnchor + 32
            $0.centerXAnchor == contentView.centerXAnchor
            $0.bottomAnchor == contentView.bottomAnchor - 34
        }
    }
}
