// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import Then
import Anchorage
import SoraUI
import SoraUIKit

protocol NodesCellDelegate: AnyObject {
    func onAction(_ action: NodeAction)
}

final class NodesCell: SoramitsuTableViewCell {

    private var delegate: NodesCellDelegate?

    // MARK: - Outlets

    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
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
            $0.sora.cornerRadius = .max
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
        clipsToBounds = false

        contentView.addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(stackView)

        containerView.do {
            $0.topAnchor == contentView.topAnchor
            $0.bottomAnchor == contentView.bottomAnchor - 16
            $0.horizontalAnchors == contentView.horizontalAnchors + 16
        }

        titleLabel.do {
            $0.topAnchor == contentView.topAnchor + 24
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
        }

        stackView.do {
            $0.topAnchor == titleLabel.bottomAnchor + 1
            $0.leadingAnchor == containerView.leadingAnchor + 32
            $0.centerXAnchor == containerView.centerXAnchor
            $0.bottomAnchor == containerView.bottomAnchor - 34
        }
    }
}
