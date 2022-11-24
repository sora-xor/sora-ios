/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage
import SoraUI
import SoraSwiftUI

protocol NodesCellDelegate: AnyObject {
    func onAction(_ action: NodeAction)
}

final class NodesCell: SoramitsuTableViewCell {

    private var delegate: NodesCellDelegate?

    // MARK: - Outlets

    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.layer.cornerRadius = 32
            $0.layer.masksToBounds = true
            $0.sora.shadow = .default
        }
    }()

    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.headline4
            $0.sora.textColor = .fgSecondary
            $0.numberOfLines = 1
        }
    }()

    private var stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.layer.cornerRadius = 32
            $0.sora.distribution = .fill
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

extension NodesCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? NodesViewModel else { return }

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        viewModel.nodesModels.forEach { node in
            let view = NodeView()
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
        titleLabel.sora.text = viewModel.header.uppercased()
        delegate = viewModel.delegate
    }
}

private extension NodesCell {

    func configure() {
        selectionStyle = .none

        contentView.addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(stackView)

        containerView.do {
            $0.topAnchor == contentView.topAnchor
            $0.bottomAnchor == contentView.bottomAnchor - 16
            $0.trailingAnchor == contentView.trailingAnchor - 16
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        titleLabel.do {
            $0.topAnchor == contentView.topAnchor + 24
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.trailingAnchor == containerView.trailingAnchor - 24
        }

        stackView.do {
            $0.topAnchor == titleLabel.bottomAnchor + 1
            $0.leadingAnchor == containerView.leadingAnchor + 32
            $0.centerXAnchor == containerView.centerXAnchor
            $0.bottomAnchor == containerView.bottomAnchor - 34
        }
    }
}
