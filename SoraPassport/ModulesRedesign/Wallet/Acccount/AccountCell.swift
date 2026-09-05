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
import SoraUIKit
import SoraKeystore
import SoraFoundation

final class AccountCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private var accountItem: AccountTableViewItem?
    private lazy var accountButton = WalletUX.button("") { [weak self] in
        guard let self, let item = self.accountItem else { return }
        item.accountHandler?(item)
    }
    private lazy var networkButton = WalletUX.button("SORA2 · Change network") { [weak self] in self?.accountItem?.networkHandler?() }
    private lazy var sendButton = WalletUX.button("Send", primary: true) { [weak self] in self?.accountItem?.sendHandler?() }
    private lazy var receiveButton = WalletUX.button("Receive") { [weak self] in self?.accountItem?.scanQRHandler?() }
    private let actions = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let stack = UIStackView(arrangedSubviews: [accountButton, networkButton, actions])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        accountButton.contentHorizontalAlignment = .leading
        accountButton.configuration?.image = UIImage(systemName: "chevron.down")
        accountButton.configuration?.imagePlacement = .trailing
        accountButton.configuration?.imagePadding = 8
        networkButton.contentHorizontalAlignment = .leading
        actions.distribution = .fillEqually
        actions.spacing = 12
        actions.addArrangedSubview(sendButton)
        actions.addArrangedSubview(receiveButton)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let axis: NSLayoutConstraint.Axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        if actions.axis != axis { actions.axis = axis }
    }
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AccountTableViewItem else { return }
        accountItem = item
        accountButton.configuration?.title = item.accountName
        accountButton.accessibilityLabel = item.accountName
        accountButton.accessibilityHint = WalletUX.text("Change account")
        networkButton.isHidden = !SettingsManager.shared.nexusEnabled
    }
}
