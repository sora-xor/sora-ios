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

final class AccountTableViewCell: SoramitsuTableViewCell {

    // MARK: - Outlets
    private lazy var itemView: AccountMenuItemView = {
        AccountMenuItemView(frame: .zero)
    }()

    // MARK: - Init

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
        contentView.addSubview(itemView)
    }
    
    func setupConstraints() {
        itemView.leftAnchor == contentView.leftAnchor + 24
        itemView.rightAnchor == contentView.rightAnchor - 24
        itemView.topAnchor == contentView.topAnchor
        itemView.bottomAnchor == contentView.bottomAnchor
    }
}

extension AccountTableViewCell: SoramitsuTableViewCellProtocol {

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AccountMenuItem else {
            return
        }
        
        itemView.bind(model: item)
        itemView.addTapGesture(with: { recognizer in
            item.onTap?()
        })
    }
    
}
