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

import SoraUIKit
import UIKit

final class ReceiveCell: SoramitsuTableViewCell {
    let card = ReceiveQRView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                          withHorizontalFittingPriority horizontal: UILayoutPriority,
                                          verticalFittingPriority vertical: UILayoutPriority) -> CGSize {
        let row = readableFrame(for: CGRect(origin: .zero, size: targetSize))
        card.sizeCode(width: row.width - 64)
        return super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontal,
                                             verticalFittingPriority: vertical)
    }
}

extension ReceiveCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ReceiveItem else { return }
        card.viewModel = ReceiveQRViewModel(name: item.name, address: item.address, qrImage: item.qrImage,
                                            shareHandler: item.shareHandler, accountTapHandler: item.accountTapHandler,
                                            avatar: item.avatar, notice: item.notice, amount: item.sendAssetViewModel,
                                            isGenerating: item.isGenerating)
    }
}
