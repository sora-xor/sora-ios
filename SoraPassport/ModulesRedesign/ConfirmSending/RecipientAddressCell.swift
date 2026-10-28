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
import SSFUtils
import UIKit

final class RecipientAddressCell: SoramitsuTableViewCell {
    private let generator = PolkadotIconGenerator()
    public lazy var recipientView = RecipientAddressView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        recipientView.contactView.arrowImageView.isHidden = true
        contentView.addSubviews(recipientView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            recipientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recipientView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            recipientView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            recipientView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension RecipientAddressCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? RecipientAddressItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        recipientView.contactView.accountTitle.sora.text = item.address
        recipientView.contactView.accountImageView.image = try? generator.generateFromAddress(item.address)
            .imageWithFillColor(UIColor.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
    }
}

