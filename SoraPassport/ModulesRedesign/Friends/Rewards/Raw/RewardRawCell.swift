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

final class RewardRawCell: SoramitsuTableViewCell {

    // MARK: - Outlets
    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
        }
    }()
    
    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.textM
            $0.sora.lineBreakMode = .byTruncatingMiddle
        }
    }()

    private var amountLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.alignment = .right
            $0.sora.font = FontType.textM
            $0.sora.lineBreakMode = .byTruncatingMiddle
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
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

    override func layoutSubviews() {
        super.layoutSubviews()

        var path = UIBezierPath()

        path.append(UIBezierPath(rect: CGRect(x: -3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height + 10)))

        path.append(UIBezierPath(rect: CGRect(x: containerView.bounds.width + 3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height + 10)))

        containerView.layer.shadowPath = path.cgPath
    }
}

extension RewardRawCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? RewardRawViewModel else { return }
        titleLabel.sora.text = viewModel.title
        amountLabel.sora.text = "\(viewModel.amount) " + viewModel.assetSymbol
    }
}

private extension RewardRawCell {

    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none
        sora.clipsToBounds = true

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(amountLabel)

        containerView.do {
            $0.topAnchor == contentView.topAnchor
            $0.bottomAnchor == contentView.bottomAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.heightAnchor == 40
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        titleLabel.do {
            $0.centerYAnchor == containerView.centerYAnchor
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.trailingAnchor == amountLabel.leadingAnchor - 20
            $0.widthAnchor >= 100
        }

        amountLabel.do {
            $0.centerYAnchor == containerView.centerYAnchor
            $0.trailingAnchor == containerView.trailingAnchor - 24
        }
    }
}
