// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
