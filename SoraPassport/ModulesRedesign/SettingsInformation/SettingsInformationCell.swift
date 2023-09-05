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

import SoraUIKit
import Anchorage

final class SettingsInformationCell: SoramitsuTableViewCell {
    
    let informationItem: InformationItemView = {
        let view = InformationItemView(frame: .zero)
        view.horizontalStack.layer.cornerRadius = 0
        view.sora.shadow = .none
        view.sora.clipsToBounds = false
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
        contentView.addSubview(informationItem)
    }

    func setupConstraints() {
        informationItem.leftAnchor == contentView.leftAnchor + 16
        informationItem.rightAnchor == contentView.rightAnchor - 16
        informationItem.topAnchor == contentView.topAnchor
        informationItem.bottomAnchor == contentView.bottomAnchor
    }
}

extension SettingsInformationCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? InformationItem else {
            return
        }

        informationItem.titleLabel.sora.text = item.title
        
        if let subtitle = item.subtitle {
            informationItem.set(subtitle: subtitle)
        }
        
        informationItem.leftImageView.sora.picture = item.picture
        informationItem.leftImageView.isHidden = item.picture == nil

        switch item.rightItem {
        case .arrow:
            informationItem.addArrow()
        case .link:
            informationItem.addLink()
        }
        
        switch item.position {
        case .first:
            informationItem.addSeparator()
            informationItem.horizontalStack.sora.cornerMask = .top

        case .last:
            informationItem.horizontalStack.sora.cornerMask = .bottom
    
        default:
            informationItem.horizontalStack.sora.cornerMask = .none
            informationItem.addSeparator()
        }

        informationItem.onTap = item.onTap
    }
}

