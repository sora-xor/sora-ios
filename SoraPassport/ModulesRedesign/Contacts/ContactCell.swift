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
import Anchorage
import SSFUtils
import UIKit

final class ContactCell: SoramitsuTableViewCell {
    private let generator = PolkadotIconGenerator()
    
    private let contactView: ContactView = ContactView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        sora.clipsToBounds = true
        contactView.sora.shadow = .small
        contentView.addSubview(contactView)
    }
    
    func setupConstraints() {
        
        NSLayoutConstraint.activate([
            contactView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contactView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contactView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contactView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
}

extension ContactCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ContactCellItem else {
            return
        }
        contactView.accountTitle.sora.text = item.title
        contactView.accountImageView.image = try? generator.generateFromAddress(item.title)
            .imageWithFillColor(UIColor.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
    }
}
