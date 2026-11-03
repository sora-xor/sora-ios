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
    /// The classic header: the account name and an arrow that opens the
    /// account list, and the QR button (receive and scan) on the right.
    private let accountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.font = FontType.displayS
        label.sora.textColor = .fgPrimary
        label.sora.lineBreakMode = .byTruncatingMiddle
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    private let arrowImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.image = R.image.wallet.rightArrow()?.imageFlippedForRightToLeftLayoutDirection()
        view.sora.tintColor = .fgPrimary
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }()
    private lazy var accountButton: SoramitsuControl = {
        let view = SoramitsuControl()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self, let item = self.accountItem else { return }
            item.accountHandler?(item)
        }
        return view
    }()
    private lazy var scanQrButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 40, height: 40))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .accentTertiary
        view.sora.backgroundColor = .bgSurface
        view.sora.image = R.image.wallet.qrScan()
        view.sora.cornerRadius = .circle
        view.sora.clipsToBounds = false
        view.accessibilityLabel = WalletUX.text("Receive")
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.accountItem?.scanQRHandler?()
        }
        return view
    }()
    private let headerRow = UIView()
    private let capabilityReason = UILabel()
    private let capabilityBadge = UILabel()
    private lazy var restoreKeysButton = WalletUX.button("Restore keys for this account") { [weak self] in
        self?.accountItem?.restoreKeysHandler?()
    }
    private let restoreTitle = UILabel()
    private lazy var restoreTitleMinimumHeight = restoreTitle.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    private lazy var restoreTitleBottom = restoreTitle.bottomAnchor.constraint(equalTo: restoreKeysButton.bottomAnchor, constant: -15)
    private lazy var reasonMinimumHeight = capabilityReason.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    private lazy var badgeMinimumHeight = capabilityBadge.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        clipsToBounds = false
        contentView.clipsToBounds = false
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(accountLabel)
        headerRow.addSubview(arrowImageView)
        headerRow.addSubview(accountButton)
        headerRow.addSubview(scanQrButton)
        // A wallet that cannot sign says so under the header, with its repair.
        let stack = UIStackView(arrangedSubviews: [headerRow, capabilityBadge, capabilityReason, restoreKeysButton])
        stack.axis = .vertical
        stack.spacing = 4
        stack.setCustomSpacing(8, after: headerRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        WalletSafeMode.body(capabilityReason, alignment: .natural)
        // Required measured heights protect visible text. Intrinsic resistance
        // must still allow UIStackView to collapse hidden capability rows.
        capabilityReason.setContentCompressionResistancePriority(UILayoutPriority(999), for: .vertical)
        capabilityBadge.setContentCompressionResistancePriority(UILayoutPriority(999), for: .vertical)
        capabilityBadge.font = .preferredFont(forTextStyle: .caption1)
        capabilityBadge.adjustsFontForContentSizeCategory = true
        capabilityBadge.textColor = WalletUX.foreground
        capabilityBadge.numberOfLines = 0
        capabilityReason.lineBreakMode = .byWordWrapping
        capabilityBadge.lineBreakMode = .byWordWrapping
        capabilityBadge.accessibilityIdentifier = "wallet-selected-account-capability-badge"
        capabilityReason.accessibilityIdentifier = "wallet-selected-account-read-only-reason"
        restoreKeysButton.accessibilityIdentifier = "wallet-selected-account-restore-keys"
        // UIButton.Configuration does not reliably contribute its wrapped
        // title height to UITableView's self-sizing pass. A constrained label
        // keeps the complete action and padding inside the capsule.
        restoreTitle.text = restoreKeysButton.configuration?.title
        restoreKeysButton.accessibilityLabel = restoreTitle.text
        restoreKeysButton.configuration?.title = nil
        restoreTitle.numberOfLines = 0
        restoreTitle.lineBreakMode = .byWordWrapping
        restoreTitle.textAlignment = .center
        restoreTitle.textColor = WalletUX.foreground
        restoreTitle.isAccessibilityElement = false
        restoreTitle.accessibilityIdentifier = "wallet-selected-account-restore-title"
        restoreTitle.setContentCompressionResistancePriority(.required, for: .vertical)
        restoreTitle.translatesAutoresizingMaskIntoConstraints = false
        restoreKeysButton.addSubview(restoreTitle)
        NSLayoutConstraint.activate([
            restoreTitle.leadingAnchor.constraint(equalTo: restoreKeysButton.leadingAnchor, constant: 20),
            restoreTitle.trailingAnchor.constraint(equalTo: restoreKeysButton.trailingAnchor, constant: -20),
            restoreTitle.topAnchor.constraint(equalTo: restoreKeysButton.topAnchor, constant: 15),
            restoreTitleBottom,
            restoreTitleMinimumHeight
        ])
        updateRestoreTitle()
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            accountLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            accountLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            arrowImageView.leadingAnchor.constraint(equalTo: accountLabel.trailingAnchor, constant: 12),
            arrowImageView.centerYAnchor.constraint(equalTo: accountLabel.centerYAnchor),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.trailingAnchor.constraint(lessThanOrEqualTo: scanQrButton.leadingAnchor, constant: -12),
            accountButton.leadingAnchor.constraint(equalTo: accountLabel.leadingAnchor),
            accountButton.trailingAnchor.constraint(equalTo: arrowImageView.trailingAnchor),
            accountButton.topAnchor.constraint(equalTo: headerRow.topAnchor),
            accountButton.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor),
            scanQrButton.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
            scanQrButton.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            scanQrButton.topAnchor.constraint(equalTo: headerRow.topAnchor),
            scanQrButton.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    private func updateRestoreTitle() {
        restoreTitle.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: FontType.buttonM.font, maximumPointSize: 26, compatibleWith: traitCollection)
        restoreTitle.textColor = WalletUX.foreground
        updateRestoreWidth(contentView.bounds.width)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateRestoreTitle()
    }
    override func layoutSubviews() {
        updateRestoreWidth(contentView.bounds.width)
        super.layoutSubviews()
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                         withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                         verticalFittingPriority: UILayoutPriority) -> CGSize {
        // The label is inside a configuration button, so self-sizing needs its
        // actual wrapping width before the table computes the row's height.
        updateRestoreWidth(targetSize.width)
        return super.systemLayoutSizeFitting(targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority)
    }

    private func updateRestoreWidth(_ width: CGFloat) {
        restoreTitleBottom.isActive = !restoreKeysButton.isHidden
        updateWrappedLabel(capabilityReason, minimumHeight: reasonMinimumHeight, width: width - 48)
        updateWrappedLabel(capabilityBadge, minimumHeight: badgeMinimumHeight, width: width - 48)
        let available = width - 48 - 40
        updateWrappedLabel(restoreTitle, minimumHeight: restoreTitleMinimumHeight,
                           width: available, hidden: restoreKeysButton.isHidden)
    }

    private func updateWrappedLabel(_ label: UILabel, minimumHeight: NSLayoutConstraint,
                                    width: CGFloat, hidden: Bool = false) {
        minimumHeight.isActive = !hidden && !label.isHidden
        guard width > 0 else { return }
        if label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
            label.invalidateIntrinsicContentSize()
        }
        // UIKit can cache the label's one-line height while a self-sizing cell
        // changes width or Dynamic Type. Measure the wrapped text explicitly,
        // including fallback fonts used by localized titles.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let requiredHeight = ceil(((label.text ?? "") as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: label.font as Any, .paragraphStyle: paragraph], context: nil).height)
        if minimumHeight.constant != requiredHeight {
            minimumHeight.constant = requiredHeight
        }
    }
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AccountTableViewItem else { return }
        accountItem = item
        accountLabel.sora.text = item.accountName
        accountButton.accessibilityLabel = item.accountName
        accountButton.accessibilityHint = WalletUX.text("Change account")
        capabilityReason.text = item.capability.reason
        capabilityBadge.text = item.capability.badge
        capabilityBadge.isHidden = item.capability.badge == nil
        capabilityReason.isHidden = item.capability == .signing
        restoreKeysButton.isHidden = !item.capability.canRestore
        updateRestoreWidth(contentView.bounds.width)
    }
}
