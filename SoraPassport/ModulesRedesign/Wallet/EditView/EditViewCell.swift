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
import SoraUIKit
import SnapKit

final class EditViewCell: SoramitsuTableViewCell {
    
    private var editViewItem: EditViewItem?
    
    private var editButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.editView(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM ,
                                      textColor: .accentSecondary,
                                      alignment: .center)
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 16
        button.sora.cornerRadius = .circle
        button.sora.attributedText = title
        button.sora.isUserInteractionEnabled = false
        button.sora.backgroundColor = .bgSurface
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupHierarchy()
        setupLayout()
        
        SoramitsuUI.updates.addObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupHierarchy() {
        contentView.addSubview(editButton)
    }
    
    private func setupLayout() {
        editButton.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(8)
            make.center.equalTo(contentView)
            make.height.equalTo(40)
        }
    }
}

extension EditViewCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? EditViewItem else {
            assertionFailure("Incorect type of item")
            return
        }
        editViewItem = item
    }
}

extension EditViewCell: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        editButton.sora.backgroundColor = .bgSurface
    }
}
