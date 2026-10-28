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
import SoraFoundation

final class MoreMenuCell: SoramitsuTableViewCell {

    let categoryItem: CategoryItem = {
        let view = CategoryItem(frame: .zero)
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupView() {
        contentView.addSubview(categoryItem)
    }

    func setupConstraints() {
        categoryItem.leadingAnchor == contentView.leadingAnchor + 16
        categoryItem.trailingAnchor == contentView.trailingAnchor - 16
        categoryItem.topAnchor == contentView.topAnchor + 8
        categoryItem.bottomAnchor == contentView.bottomAnchor - 8
    }
    
    func updateLayout() {
        let isRTL: Bool = LocalizationManager.shared.isRightToLeft
        let semanticContentAttribute: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        categoryItem.horizontalStack.semanticContentAttribute = semanticContentAttribute
        categoryItem.verticalStack.semanticContentAttribute = semanticContentAttribute
        categoryItem.subtitleView.semanticContentAttribute = semanticContentAttribute
        categoryItem.titleLabel.sora.alignment = isRTL ? .right : .left
        categoryItem.subtitleLabel.sora.alignment = isRTL ? .right : .left
    }
}

extension MoreMenuCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? MoreMenuItem else {
            return
        }

        categoryItem.titleLabel.sora.text = item.title
        categoryItem.subtitleLabel.sora.text = item.subtitle
        categoryItem.rightImageView.sora.picture = item.picture

        if let circleColor = item.circleColor {
            categoryItem.addCircle()
            categoryItem.circle.sora.backgroundColor = circleColor
        } else {
            categoryItem.hideCircle()
        }

        if let circleColorStream = item.circleColorStream {
            Task {
                for await color in circleColorStream {
                    if let color = color {
                        categoryItem.addCircle()
                        categoryItem.circle.sora.backgroundColor = color
                    } else {
                        categoryItem.hideCircle()
                    }
                }
            }
        }

        if let subtitleStream = item.subtitleStream {
            Task {
                for await subtitle in subtitleStream {
                    categoryItem.subtitleLabel.sora.text = subtitle
                }
            }
        }

        updateLayout()
    }
}

