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

import SoraFoundation

import Combine

enum TransferableActionType {
    case send
    case receive
    case swap
    case frozenDetails
// TODO: Temporary Removal of X1
//    case buy
}

final class TransferableCell: SoramitsuTableViewCell {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var transferableItem: TransferableItem? {
        didSet {
            guard let item = transferableItem else { return }
            item.service.$balanceAmount
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let value = value, let item = self?.transferableItem else { return }
                    self?.update(balance: value, symbol: item.assetInfo.symbol )
                    self?.sendButton.sora.isHidden = value.isZero
                }
                .store(in: &cancellables)
            item.service.$fiatBalanceText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let value = value, !value.isEmpty else { return }
                    self?.fiatLabel.sora.text = value
                }
                .store(in: &cancellables)
            item.service.$publishedFrozenAmount
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let value = value, let item = self?.transferableItem else { return }
                    self?.frozenContainerView.sora.isHidden = (value.decimalValue ).isZero
                    self?.frozenAmountLabel.sora.text = (value.stringValue ) + " " + item.assetInfo.symbol
                }
                .store(in: &cancellables)
            item.service.$frozenFiat
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let value = value, !value.isEmpty else { return }
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

// TODO: Temporary Removal of X1
//    private lazy var buyFiatButton: AssetActionView = {
//        let view = AssetActionView()
//        view.titleLabel.sora.text = R.string.localizable.commonBuy(preferredLanguages: .currentLocale)
//        view.button.sora.leftImage = R.image.wallet.buy()
//        view.button.sora.horizontalOffset = 16
//        view.accessibilityIdentifier = "assetDetails.buy"
//        view.sora.addHandler(for: .touchUpInside) { [weak self] in
//            self?.transferableItem?.actionHandler?(.buy)
//        }
//        return view
//    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(containerView)
        actionsStackView.addArrangedSubviews(sendButton, receiveButton, swapButton) //, buyFiatButton) TODO: Temporary Removal of X1 
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
        
        update(balance: item.balance.decimalValue, symbol: item.assetInfo.symbol)
        sendButton.sora.isHidden = item.balance.decimalValue.isZero
        
        fiatLabel.sora.text = item.fiat
// TODO: Temporary Removal of X1
//        buyFiatButton.sora.isHidden = item.assetInfo != .xor
        frozenContainerView.sora.isHidden = (item.frozenAmount?.decimalValue ?? Decimal(0)).isZero
        frozenAmountLabel.sora.text = (item.frozenAmount?.stringValue ?? "") + " " + item.assetInfo.symbol
        frozenFiatAmountLabel.sora.text = item.frozenFiatAmount
    }
}

