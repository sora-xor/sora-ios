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
import SnapKit
import SoraFoundation
import Combine

final class PolkaswapCell: SoramitsuTableViewCell {
    
    private var polkaswapItem: PolkaswapItem?
    private let localizationManager = LocalizationManager.shared
    
    private var cancellables: Set<AnyCancellable> = []
    private weak var viewModel: LiquidityViewModelProtocol? {
        didSet {
            guard let viewModel = viewModel else { return }
            viewModel.firstAssetPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] asset in
                    guard let self else { return }
                    asset.$balance
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] balance in
                            self?.assetsView.firstAsset.sora.fullFiatText = balance
                        }
                        .store(in: &cancellables)
                    
                    asset.$symbol
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] symbol in
                            if !symbol.isEmpty {
                                self?.assetsView.firstAsset.sora.assetSymbol = symbol
                            }
                        }
                        .store(in: &cancellables)
                    
                    asset.$image
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] image in
                            guard let image else { return }
                            self?.assetsView.firstAsset.sora.assetImage = image
                        }
                        .store(in: &cancellables)
                    
                    asset.$fiat
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] fiat in
                            self?.assetsView.firstAsset.sora.inputedFiatAmountText = fiat
                        }
                        .store(in: &cancellables)
                    
                    asset.$state
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] state in
                            self?.assetsView.firstAsset.sora.state = state
                        }
                        .store(in: &cancellables)
                    
                    asset.$amountColor
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] amountColor in
                            self?.assetsView.firstAsset.textField.sora.textColor = amountColor
                        }
                        .store(in: &cancellables)
                    
                    asset.$fiatColor
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] fiatColor in
                            self?.assetsView.firstAsset.inputedFiatAmountLabel.sora.textColor = fiatColor
                        }
                        .store(in: &cancellables)
                    
                    asset.$amount
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] amount in
                            self?.assetsView.firstAsset.textField.sora.text = amount == "0" ? "" : amount
                        }
                        .store(in: &cancellables)
                    
                    asset.$isFirstResponder
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] isFirstResponder in
                            if isFirstResponder {
                                self?.assetsView.firstAsset.textField.becomeFirstResponder()
                            }
                        }
                        .store(in: &cancellables)
                }
                .store(in: &cancellables)
            
            viewModel.secondAssetPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] asset in
                    guard let self else { return }
                    asset.$balance
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] balance in
                            self?.assetsView.secondAsset.sora.fullFiatText = balance
                        }
                        .store(in: &cancellables)
                    
                    asset.$symbol
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] symbol in
                            if !symbol.isEmpty {
                                self?.assetsView.secondAsset.sora.assetSymbol = symbol
                            }
                        }
                        .store(in: &cancellables)
                    
                    asset.$image
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] image in
                            guard let image else { return }
                            self?.assetsView.secondAsset.sora.assetImage = image
                        }
                        .store(in: &cancellables)
                    
                    asset.$fiat
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] fiat in
                            self?.assetsView.secondAsset.sora.inputedFiatAmountText = fiat
                        }
                        .store(in: &cancellables)
                    
                    asset.$state
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] state in
                            self?.assetsView.secondAsset.sora.state = state
                        }
                        .store(in: &cancellables)
                    
                    asset.$amountColor
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] amountColor in
                            self?.assetsView.secondAsset.textField.sora.textColor = amountColor
                        }
                        .store(in: &cancellables)
                    
                    asset.$fiatColor
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] fiatColor in
                            self?.assetsView.secondAsset.inputedFiatAmountLabel.sora.textColor = fiatColor
                        }
                        .store(in: &cancellables)
                    
                    asset.$amount
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] amount in
                            self?.assetsView.secondAsset.textField.sora.text = amount == "0" ? "" : amount
                        }
                        .store(in: &cancellables)
                    
                    asset.$isFirstResponder
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] isFirstResponder in
                            if isFirstResponder {
                                self?.assetsView.secondAsset.textField.becomeFirstResponder()
                            }
                        }
                        .store(in: &cancellables)
                }
                .store(in: &cancellables)
            
            viewModel.slippagePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] title in
                    self?.optionsView.slipageButton.sora.title = title
                }
                .store(in: &cancellables)
            
            viewModel.marketPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] title in
                    self?.optionsView.marketButton.sora.title = title
                }
                .store(in: &cancellables)
            
            viewModel.reviewButtonPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] title in
                    self?.reviewLiquidity.sora.title = title
                }
                .store(in: &cancellables)

            viewModel.isMiddleButtonEnabledPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isEnabled in
                    self?.assetsView.middleButton.sora.isEnabled = isEnabled
                }
                .store(in: &cancellables)
            
            viewModel.isButtonEnabledPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isEnabled in
                    self?.reviewLiquidity.sora.isEnabled = isEnabled
                    if isEnabled {
                        self?.reviewLiquidity.sora.backgroundColor = .additionalPolkaswap
                    }
                }
                .store(in: &cancellables)
            
            viewModel.isNeedLoadingStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isNeedLoadingState in
                    self?.reviewLiquidity.sora.loadingPlaceholder.type = isNeedLoadingState ? .shimmer : .none
                }
                .store(in: &cancellables)
            
            viewModel.isMarketLoadingStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isNeedLoadingState in
                    self?.optionsView.marketButton.sora.loadingPlaceholder.type = isNeedLoadingState ? .shimmer : .none
                }
                .store(in: &cancellables)
            
            viewModel.warningViewModelPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] viewModel in
                    guard let viewModel = viewModel else { return }
                    self?.warningView.setupView(with: viewModel)
                }
                .store(in: &cancellables)
            
            viewModel.firstLiquidityViewModelPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] viewModel in
                    guard let viewModel = viewModel else { return }
                    self?.firstLiquidityWarningView.setupView(with: viewModel)
                }
                .store(in: &cancellables)
        }
    }
    
    private let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .center
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var assetsView: InputAssetsView = {
        let view = InputAssetsView()
        view.middleButton.sora.image = viewModel?.actionButtonImage
        view.middleButton.sora.tintColor = .additionalPolkaswap
        view.middleButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard 
                let self = self,
                let viewModel = self.viewModel
            else { return }
            viewModel.middleButtonActionHandler?()
            
            if viewModel.isSwap {
                self.rotateAnimation()
            }
        }
        
        view.firstAsset.sora.assetSymbol = R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
        view.firstAsset.sora.fullFiatText = viewModel?.firstFieldEmptyStateFullFiatText
        view.firstAsset.sora.text = ""
        view.firstAsset.sora.assetImage = R.image.wallet.emptyToken()
        view.firstAsset.textField.inputAccessoryView = accessoryView
        view.firstAsset.sora.assetChoiceHandler = { [weak self] in
            self?.viewModel?.choiсeBaseAssetButtonTapped()
        }
        view.firstAsset.textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.viewModel?.focusedField = .one
        }
        view.firstAsset.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.reviewLiquidity.sora.isEnabled = false
            self?.viewModel?.focusedField = .one
            self?.viewModel?.inputedFirstAmount = Decimal(string: self?.assetsView.firstAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel?.recalculate(field: .one)
        }
        
        view.secondAsset.sora.assetSymbol = R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
        view.secondAsset.sora.fullFiatText = viewModel?.secondFieldEmptyStateFullFiatText
        view.secondAsset.sora.text = ""
        view.secondAsset.sora.assetImage = R.image.wallet.emptyToken()
        view.secondAsset.textField.inputAccessoryView = accessoryView
        view.secondAsset.sora.assetChoiceHandler = { [weak self] in
            self?.viewModel?.choiсeTargetAssetButtonTapped()
        }
        view.secondAsset.textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.viewModel?.focusedField = .two
        }
        view.secondAsset.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.reviewLiquidity.sora.isEnabled = false
            self?.viewModel?.focusedField = .two
            self?.viewModel?.inputedSecondAmount = Decimal(string: self?.assetsView.secondAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel?.recalculate(field: .two)
        }
        return view
    }()
    
    private lazy var optionsView: OptionsView = {
        let view = OptionsView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.marketLabel.sora.isHidden = !(viewModel?.isSwap ?? false)
        view.marketButton.sora.isHidden = !(viewModel?.isSwap ?? false)
        view.slipageButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel?.changeSlippageTolerance()
        }
        view.marketButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel?.changeMarket()
        }
        return view
    }()
    
    private lazy var warningView: WarningView = {
        let view = WarningView()
        view.sora.isHidden = true
        return view
    }()
    
    private lazy var reviewLiquidity: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.title = R.string.localizable.review(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.isEnabled = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel?.reviewButtonTapped()
        }
        return button
    }()
    
    private lazy var firstLiquidityWarningView: WarningView = {
        let view = WarningView()
        view.sora.isHidden = true
        return view
    }()
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    
    private func setupHierarchy() {
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubview(assetsView)
        stackView.addArrangedSubview(optionsView)
        stackView.addArrangedSubview(firstLiquidityWarningView)
        stackView.addArrangedSubview(warningView)
        stackView.addArrangedSubview(reviewLiquidity)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            assetsView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            assetsView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            warningView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            warningView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            firstLiquidityWarningView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            firstLiquidityWarningView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),

            reviewLiquidity.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            reviewLiquidity.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
        ])
    }
    
    private func rotateAnimation() {
        UIView.animate(withDuration: 0.5) {
            self.assetsView.middleButton.transform = CGAffineTransform(rotationAngle: .pi)
        }

        UIView.animate(
            withDuration: 0.5,
            delay: 0.45,
            options: UIView.AnimationOptions.curveEaseIn
        ) {
            self.assetsView.middleButton.transform = CGAffineTransform(rotationAngle: 2 * .pi)
        }
    }
}

extension PolkaswapCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PolkaswapItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        polkaswapItem = item
        
        viewModel = item.viewModel
    }
}
