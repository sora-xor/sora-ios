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
import SoraFoundation

class AppSettingsCardCell: SoramitsuTableViewCell {

    let containerView: SoramitsuView = {
        let container = SoramitsuView()
        container.sora.backgroundColor = .bgSurface
        container.sora.cornerRadius = .max
        container.sora.clipsToBounds = true
        container.sora.shadow = .default
        return container
    }()

    let stack: SoramitsuStackView = {
        let view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        view.sora.distribution = .fill

        return view
    }()
    
    private var localizationManager = LocalizationManager.shared

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupView() {
        containerView.addSubview(stack)
        contentView.addSubview(containerView)
    }

    func setupConstraints() {
        containerView.leftAnchor == contentView.leftAnchor + 16
        containerView.rightAnchor == contentView.rightAnchor - 16
        containerView.topAnchor == contentView.topAnchor + 8
        containerView.bottomAnchor == contentView.bottomAnchor - 8

        stack.edgeAnchors == containerView.edgeAnchors
    }
}

extension AppSettingsCardCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AppSettingsCardItem else {
            return
        }
        
        stack.removeArrangedSubviews()

        if let title = item.title {
            let titleView = self.titleView(for: title)
            stack.addArrangedSubviews(titleView)
        }

        for appSettingsItem in item.menuItems {
            let subview = self.menuItemView(from: appSettingsItem)
            stack.addArrangedSubviews(subview)
        }
    }

    private func titleView(for title: String) -> MenuTitleItem {
        let view = MenuTitleItem(frame: .zero)
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        view.titleLabel.sora.text = title
        view.titleLabel.sora.alignment = alignment
        return view
    }

    private func menuItemView(from item: AppSettingsItem) -> MenuItem {
        let view = MenuItem(frame: .zero)
        view.horizontalStack.layer.cornerRadius = 0
        view.sora.shadow = .none
        view.sora.clipsToBounds = false

        view.titleLabel.sora.text = item.title
        view.leftImageView.sora.picture = item.picture
        view.leftImageView.isHidden = item.picture == nil

        switch item.rightItem {
        case .arrow:
            view.addArrow()
        case .switcher(let state):
            view.addSwitcher()
            view.switcher.isEnabled = state != .disabled
            view.switcher.isOn = state == .on
        }

        view.onTap = item.onTap
        view.onSwitch = item.onSwitch
        
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        view.titleLabel.sora.alignment = alignment
        
        return view
    }

}

