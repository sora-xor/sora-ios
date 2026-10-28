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

import SoraFoundation

import Combine

enum TransferableActionType {
    case send
    case receive
    case swap
    case frozenDetails
}

final class TransferableCell: SoramitsuTableViewCell {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var transferableItem: TransferableItem? {
        didSet {
            guard let item = transferableItem else { return }
            // The cell is reused: what an earlier item published is not
            // for this one.
            cancellables.removeAll()
            item.service.$balanceUnavailable
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.showBalance()
                }
                .store(in: &cancellables)
            item.service.$balanceAmount
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.showBalance()
                }
                .store(in: &cancellables)
            item.service.$fiatBalanceText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let value = value, !value.isEmpty,
                          self?.transferableItem?.service.balanceUnavailable == false else { return }
                    self?.fiatLabel.sora.text = value
                }
                .store(in: &cancellables)
            item.service.$publishedFrozenAmount
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let value = value, let item = self?.transferableItem,
                          !item.service.balanceUnavailable else { return }
                    self?.frozenContainerView.sora.isHidden = (value.decimalValue ).isZero
                    self?.frozenAmountLabel.sora.text = (value.stringValue ) + " " + item.assetInfo.symbol
                }
                .store(in: &cancellables)
            item.service.$frozenFiat
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let value = value, !value.isEmpty,
                          self?.transferableItem?.service.balanceUnavailable == false else { return }
                    self?.frozenFiatAmountLabel.sora.text = value
                }
                .store(in: &cancellables)
        }
    }
    
    private var localizationManager = LocalizationManager.shared
    
    private let containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.cornerRadius = .max
        view.clipsToBounds = false
        view.sora.axis = .vertical
        view.sora.alignment = .center
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    private let transferableContainerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        return view
    }()
    
    private let transferableLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.assetDetailsLiquidBalance(preferredLanguages: .currentLocale)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    private let fiatLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        return label
    }()
    
    private let balanceLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isUserInteractionEnabled = false
        label.sora.text = " "
        return label
    }()

    private let separatorView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .fgOutline
        return view
    }()
    
    private lazy var frozenContainerView: SoramitsuControl = {
        var view = SoramitsuControl()
        view.sora.isHidden = true
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.transferableItem?.actionHandler?(.frozenDetails)
        }
        return view
    }()
    
    private let frozenTitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.detailsFrozen(preferredLanguages: .currentLocale)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let logoImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.image = R.image.wallet.lock()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return view
    }()
    
    private let frozenAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.text = " "
        return label
    }()
    
    private let frozenFiatAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .right
        return label
    }()
    
    private let actionsStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .equalSpacing
        view.sora.alignment = .center
        view.sora.shadow = .small
        view.spacing = 20
        view.clipsToBounds = false
        return view
    }()
    
    private lazy var sendButton: AssetActionView = {
        let view = AssetActionView()
        view.titleLabel.sora.text = R.string.localizable.commonSend(preferredLanguages: .currentLocale)
        view.button.sora.leftImage = R.image.wallet.send()
        view.button.sora.horizontalOffset = 16
        view.accessibilityIdentifier = "assetDetails.send"
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.transferableItem?.actionHandler?(.send)
        }
        return view
    }()
    
    private lazy var receiveButton: AssetActionView = {
        let view = AssetActionView()
        view.titleLabel.sora.text = R.string.localizable.commonReceive(preferredLanguages: .currentLocale)
        view.button.sora.leftImage = R.image.wallet.receive()
        view.button.sora.horizontalOffset = 16
        view.accessibilityIdentifier = "assetDetails.receive"
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.transferableItem?.actionHandler?(.receive)
        }
        return view
    }()
    
    private lazy var swapButton: AssetActionView = {
        let view = AssetActionView()
        view.titleLabel.sora.text = R.string.localizable.historySwap(preferredLanguages: .currentLocale)
        view.button.sora.leftImage = R.image.wallet.swap()
        view.button.sora.horizontalOffset = 16
        view.accessibilityIdentifier = "assetDetails.swap"
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.transferableItem?.actionHandler?(.swap)
        }
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(containerView)
        actionsStackView.addArrangedSubviews(sendButton, receiveButton, swapButton)
        transferableContainerView.addSubviews(transferableLabel, fiatLabel, balanceLabel)
        frozenContainerView.addSubviews(frozenTitleLabel, frozenAmountLabel, frozenFiatAmountLabel, logoImageView)
        containerView.addArrangedSubviews(transferableContainerView, frozenContainerView, separatorView, actionsStackView)
        
        containerView.setCustomSpacing(16, after: transferableContainerView)
        containerView.setCustomSpacing(16, after: frozenContainerView)
        containerView.setCustomSpacing(24, after: separatorView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            transferableContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            transferableContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            separatorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            separatorView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            transferableLabel.leadingAnchor.constraint(equalTo: transferableContainerView.leadingAnchor),
            transferableLabel.topAnchor.constraint(equalTo: transferableContainerView.topAnchor),
            
            fiatLabel.trailingAnchor.constraint(equalTo: transferableContainerView.trailingAnchor),
            fiatLabel.topAnchor.constraint(equalTo: transferableContainerView.topAnchor),

            balanceLabel.leadingAnchor.constraint(equalTo: transferableContainerView.leadingAnchor),
            balanceLabel.trailingAnchor.constraint(equalTo: transferableContainerView.trailingAnchor),
            balanceLabel.topAnchor.constraint(equalTo: transferableLabel.bottomAnchor, constant: 4),
            balanceLabel.bottomAnchor.constraint(equalTo: transferableContainerView.bottomAnchor),
            
            frozenTitleLabel.leadingAnchor.constraint(equalTo: frozenContainerView.leadingAnchor),
            frozenTitleLabel.topAnchor.constraint(equalTo: frozenContainerView.topAnchor),
            
            frozenTitleLabel.leadingAnchor.constraint(equalTo: frozenContainerView.leadingAnchor),
            frozenTitleLabel.topAnchor.constraint(equalTo: frozenContainerView.topAnchor),
            
            frozenAmountLabel.leadingAnchor.constraint(equalTo: frozenContainerView.leadingAnchor),
            frozenAmountLabel.topAnchor.constraint(equalTo: frozenTitleLabel.bottomAnchor, constant: 4),
            frozenAmountLabel.bottomAnchor.constraint(equalTo: frozenContainerView.bottomAnchor),
            
            logoImageView.leadingAnchor.constraint(equalTo: frozenTitleLabel.trailingAnchor, constant: 8),
            logoImageView.centerYAnchor.constraint(equalTo: frozenTitleLabel.centerYAnchor),
            
            frozenFiatAmountLabel.trailingAnchor.constraint(equalTo: frozenContainerView.trailingAnchor),
            frozenFiatAmountLabel.topAnchor.constraint(equalTo: frozenContainerView.topAnchor),
            frozenFiatAmountLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 8),
            frozenFiatAmountLabel.bottomAnchor.constraint(equalTo: frozenTitleLabel.bottomAnchor),
            
            frozenContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            frozenContainerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            separatorView.heightAnchor.constraint(equalToConstant: 1),

            actionsStackView.heightAnchor.constraint(equalToConstant: 76)
        ])
    }
    
    private func update(balance: Decimal?, symbol: String) {
        let text = NumberFormatter.cryptoAssets.stringFromDecimal(balance ?? Decimal(0)) ?? ""
        let balanceText = text + " " + symbol
        let balanceTextReversed = symbol + " " + text

        balanceLabel.sora.text = localizationManager.isRightToLeft ? balanceTextReversed : balanceText
        balanceLabel.sora.alignment = localizationManager.isRightToLeft ? .right : .left
    }
}

extension TransferableCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? TransferableItem else {
            assertionFailure("Incorect type of item")
            return
        }
        transferableItem = item
        
        if item.balanceUnavailable {
            showBalanceUnavailable()
            return
        }

        update(balance: item.balance.decimalValue, symbol: item.assetInfo.symbol)
        sendButton.sora.isHidden = item.balance.decimalValue.isZero
        
        fiatLabel.sora.text = item.fiat
        frozenContainerView.sora.isHidden = (item.frozenAmount?.decimalValue ?? Decimal(0)).isZero
        frozenAmountLabel.sora.text = (item.frozenAmount?.stringValue ?? "") + " " + item.assetInfo.symbol
        frozenFiatAmountLabel.sora.text = item.frozenFiatAmount
    }
}

private extension TransferableCell {
    /// The balance line as the service has it now: "Balance unavailable",
    /// or the amount that was read. Runs on the main thread.
    func showBalance() {
        guard let item = transferableItem else { return }
        if item.service.balanceUnavailable {
            showBalanceUnavailable()
            return
        }
        guard let value = item.service.balanceAmount else { return }
        update(balance: value, symbol: item.assetInfo.symbol)
        sendButton.sora.isHidden = value.isZero
        // The value and the frozen part of the balance that was read; they
        // were cleared while it was unavailable.
        if let fiat = item.service.fiatBalanceText {
            fiatLabel.sora.text = fiat
        }
        if let frozen = item.service.publishedFrozenAmount {
            frozenContainerView.sora.isHidden = frozen.decimalValue.isZero
            frozenAmountLabel.sora.text = frozen.stringValue + " " + item.assetInfo.symbol
        }
        if let frozenFiat = item.service.frozenFiat {
            frozenFiatAmountLabel.sora.text = frozenFiat
        }
    }

    /// No amount, no value and no frozen part: none of them is known. An
    /// amount of zero next to the notice would contradict it. Nothing can
    /// be sent from a balance that is not known either.
    func showBalanceUnavailable() {
        balanceLabel.sora.text = WalletUX.balanceUnavailableText
        fiatLabel.sora.text = ""
        sendButton.sora.isHidden = true
        frozenContainerView.sora.isHidden = true
        frozenAmountLabel.sora.text = ""
        frozenFiatAmountLabel.sora.text = ""
    }
}

