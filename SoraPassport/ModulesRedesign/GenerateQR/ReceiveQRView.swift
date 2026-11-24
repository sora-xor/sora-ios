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
import SSFUtils
import UIKit

struct ReceiveQRViewModel {
    let name: String
    let address: String
    let qrImage: UIImage?
    var shareHandler: (() -> Void)?
    var scanQRHandler: (() -> Void)?
    var accountTapHandler: (() -> Void)?
    var avatar: UIImage?
    var notice: String?
    var amount: SendAssetViewModel?
    var isGenerating = false
}

/// The QR always has a square, opaque white quiet zone, including in short windows.
final class ReceiveQRView: SoramitsuView {
    private let generator = PolkadotIconGenerator()
    private let stack = UIStackView()
    private let codeCard = SoramitsuView()
    private let code = UIImageView()
    private let status = SoramitsuLabel()
    private let account = SoramitsuControl()
    private let avatar = UIImageView()
    private let name = SoramitsuLabel()
    private let address = SoramitsuLabel()
    private let copyIcon = UIImageView(image: UIImage(systemName: "doc.on.doc"))
    private let notice = SoramitsuLabel()
    private let amount = SendAssetView()
    let shareButton = SoramitsuButton()
    private let scanButton = SoramitsuButton()
    private var resetCopy: DispatchWorkItem?
    private lazy var square = codeCard.heightAnchor.constraint(equalTo: codeCard.widthAnchor)
    private lazy var sizing = WalletCodeSide(card: codeCard, square: square)

    var viewModel: ReceiveQRViewModel? {
        didSet {
            guard let model = viewModel else { return }
            if oldValue?.address != model.address {
                resetCopy?.cancel()
                copyIcon.image = UIImage(systemName: "doc.on.doc")
            }
            name.sora.text = model.name
            name.isHidden = model.name.isEmpty
            address.sora.text = model.address
            account.accessibilityLabel = [model.name, model.address].filter { !$0.isEmpty }.joined(separator: ", ")
            account.accessibilityHint = model.accountTapHandler == nil ? nil : R.string.localizable.commonCopyAddress(preferredLanguages: .currentLocale)
            account.accessibilityTraits = model.accountTapHandler == nil ? .staticText : .button
            copyIcon.isHidden = model.accountTapHandler == nil
            avatar.image = model.avatar ?? (try? generator.generateFromAddress(model.address)
                .imageWithFillColor(.white, size: CGSize(width: 40, height: 40), contentScale: UIScreen.main.scale))
            let newImage = model.qrImage != nil && code.image !== model.qrImage
            code.image = model.qrImage
            codeCard.isHidden = model.qrImage == nil
            status.sora.text = WalletUX.text("QR unavailable")
            status.isHidden = model.qrImage != nil || model.isGenerating
            if newImage { LitMotion.rise(codeCard, by: 8) }
            notice.sora.text = model.notice
            notice.isHidden = model.notice?.isEmpty ?? true
            amount.isHidden = model.amount == nil
            amount.setupView(with: model.amount)
            // Kit buttons have a required height. Remove absent actions from the
            // stack so UIKit never tries to collapse a fixed-height control.
            if model.shareHandler == nil {
                shareButton.removeFromSuperview()
            } else if shareButton.superview == nil {
                let index = stack.arrangedSubviews.firstIndex(of: scanButton) ?? stack.arrangedSubviews.count
                stack.insertArrangedSubview(shareButton, at: index)
            }
            if model.scanQRHandler == nil {
                scanButton.removeFromSuperview()
            } else if scanButton.superview == nil {
                stack.addArrangedSubview(scanButton)
            }
        }
    }

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        sora.backgroundColor = .custom(uiColor: .clear)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        [codeCard, status, account, notice, amount].forEach(stack.addArrangedSubview)
        let bottom = stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottom.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor), bottom,
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        codeCard.sora.backgroundColor = .custom(uiColor: .white)
        codeCard.sora.material = .solid
        codeCard.sora.cornerRadius = .max
        codeCard.sora.shadow = .small
        code.translatesAutoresizingMaskIntoConstraints = false
        code.contentMode = .scaleAspectFit
        code.layer.magnificationFilter = .nearest
        code.layer.minificationFilter = .nearest
        code.isAccessibilityElement = false
        codeCard.addSubview(code)
        square.priority = UILayoutPriority(999)
        let insetHeight = code.heightAnchor.constraint(equalTo: codeCard.heightAnchor, constant: -48)
        insetHeight.priority = UILayoutPriority(998)
        NSLayoutConstraint.activate([
            square,
            code.centerXAnchor.constraint(equalTo: codeCard.centerXAnchor),
            code.centerYAnchor.constraint(equalTo: codeCard.centerYAnchor),
            insetHeight,
            code.widthAnchor.constraint(equalTo: code.heightAnchor)
        ])

        setupAccount()
        for label in [status, notice] {
            label.sora.font = FontType.textS
            label.sora.textColor = .fgSecondary
            label.sora.numberOfLines = 0
            label.sora.alignment = .center
        }
        notice.accessibilityIdentifier = "receive.notice"
        configure(shareButton, title: R.string.localizable.commonShare(preferredLanguages: .currentLocale),
                  symbol: "square.and.arrow.up", primary: true)
        shareButton.sora.addHandler(for: .touchUpInside) { [weak self] in self?.viewModel?.shareHandler?() }
        configure(scanButton, title: R.string.localizable.commomScanQr(preferredLanguages: .currentLocale),
                  symbol: "qrcode.viewfinder", primary: false)
        scanButton.sora.addHandler(for: .touchUpInside) { [weak self] in self?.viewModel?.scanQRHandler?() }
    }

    private func setupAccount() {
        account.sora.backgroundColor = .bgSurface
        account.sora.cornerRadius = .max
        account.isAccessibilityElement = true
        account.sora.addHandler(for: .touchUpInside) { [weak self] in self?.viewModel?.accountTapHandler?() }

        name.sora.textColor = .fgSecondary
        name.sora.font = FontType.textBoldS
        name.sora.dynamicTextStyle = .headline
        name.sora.numberOfLines = 0
        address.sora.textColor = .fgPrimary
        address.sora.font = FontType.mono
        address.sora.dynamicTextStyle = .body
        address.sora.numberOfLines = 0
        address.sora.lineBreakMode = .byCharWrapping
        address.semanticContentAttribute = .forceLeftToRight
        let labels = UIStackView(arrangedSubviews: [name, address])
        labels.axis = .vertical
        labels.spacing = 3
        copyIcon.tintColor = WalletUX.accent
        copyIcon.contentMode = .scaleAspectFit
        avatar.contentMode = .scaleAspectFit
        let row = UIStackView(arrangedSubviews: [avatar, labels, copyIcon])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        account.addSubview(row)
        let copyWidth = copyIcon.widthAnchor.constraint(equalToConstant: 20)
        copyWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: account.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: account.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: account.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: account.bottomAnchor, constant: -12),
            avatar.widthAnchor.constraint(equalToConstant: 36), avatar.heightAnchor.constraint(equalTo: avatar.widthAnchor),
            copyWidth, copyIcon.heightAnchor.constraint(equalTo: copyIcon.widthAnchor)
        ])
    }

    private func configure(_ button: SoramitsuButton, title: String, symbol: String, primary: Bool) {
        let color: SoramitsuColor = primary ? .fgInverted : .accentPrimary
        button.sora.tintColor = color
        button.sora.leftImage = UIImage(systemName: symbol)
        button.sora.attributedText = SoramitsuTextItem(text: title, fontData: FontType.buttonM, textColor: color, alignment: .center)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = primary ? .accentPrimary : .bgSurface
        button.accessibilityLabel = title
        let height = button.heightAnchor.constraint(greaterThanOrEqualToConstant: primary ? 56 : 48)
        height.priority = UILayoutPriority(999)
        height.isActive = true
    }

    func addressCopied(_ value: String) {
        guard viewModel?.address == value else { return }
        resetCopy?.cancel()
        copyIcon.image = UIImage(systemName: "checkmark.circle.fill")
        LitMotion.rise(copyIcon, by: 4)
        UIAccessibility.post(notification: .announcement, argument: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
        let reset = DispatchWorkItem { [weak self] in self?.copyIcon.image = UIImage(systemName: "doc.on.doc") }
        resetCopy = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: reset)
    }

    func sizeCode(width: CGFloat) {
        sizing.update(columnWidth: codeCard.isHidden ? 0 : width, canvas: WalletDisplay.canvas(for: self))
    }

    override func layoutSubviews() {
        sizeCode(width: bounds.width)
        super.layoutSubviews()
    }
}
