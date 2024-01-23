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

import Foundation
import UIKit
import SoraUIKit

protocol LiquidityViewProtocol: ControllerBackedProtocol, Warningable {
    func update(details: [DetailViewModel])
    func updateFirstAsset(balance: String)
    func updateSecondAsset(balance: String)
    func updateFirstAsset(symbol: String, image: UIImage?)
    func updateSecondAsset(symbol: String, image: UIImage?)
    func updateFirstAsset(fiatText: String)
    func updateSecondAsset(fiatText: String)
    func updateFirstAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor)
    func updateSecondAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor)
    func update(slippageTolerance: String)
    func update(selectedMarket: String)
    func updateMiddleButton(isEnabled: Bool)
    func set(firstAmountText: String)
    func set(secondAmountText: String)
    func setupButton(isEnabled: Bool)
    func setAccessoryView(isHidden: Bool)
    func setupMarketButton(isLoadingState: Bool)
    func focus(field: FocusedField)
    func update(isNeedLoadingState: Bool)
    func updateReviewButton(title: String)
    func updateFirstLiquidityWarinignView(model: WarningViewModel)
}

final class PolkaswapViewController: SoramitsuViewController {
    
    private lazy var accessoryView: InputAccessoryView = {
        let rect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 48))
        let view = InputAccessoryView(frame: rect)
        view.delegate = viewModel
        view.variants = [ InputAccessoryVariant(displayValue: "25%", value: 0.25),
                          InputAccessoryVariant(displayValue: "50%", value: 0.5),
                          InputAccessoryVariant(displayValue: "75%", value: 0.75),
                          InputAccessoryVariant(displayValue: "100%", value: 1) ]
        return view
    }()

    private lazy var containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)
        view.stackView.spacing = 16
        view.scrollView.keyboardDismissMode = .onDrag
        view.scrollView.showsVerticalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var assetsView: InputAssetsView = {
        let view = InputAssetsView()
        view.middleButton.sora.image = viewModel.actionButtonImage
        view.middleButton.sora.tintColor = .additionalPolkaswap
        view.middleButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.viewModel.middleButtonActionHandler?()
            
            if self.viewModel.isSwap {
                self.rotateAnimation()
            }
        }
        
        view.firstAsset.sora.assetSymbol = R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
        view.firstAsset.sora.fullFiatText = viewModel.firstFieldEmptyStateFullFiatText
        view.firstAsset.sora.text = ""
        view.firstAsset.sora.assetImage = R.image.wallet.emptyToken()
        view.firstAsset.textField.inputAccessoryView = accessoryView
        view.firstAsset.sora.assetChoiceHandler = { [weak self] in
            self?.viewModel.choiсeBaseAssetButtonTapped()
        }
        view.firstAsset.textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.viewModel.focusedField = .one
        }
        view.firstAsset.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.reviewLiquidity.sora.isEnabled = false
            self?.viewModel.focusedField = .one
            self?.viewModel.inputedFirstAmount = Decimal(string: self?.assetsView.firstAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel.recalculate(field: .one)
        }
        
        view.secondAsset.sora.assetSymbol = R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
        view.secondAsset.sora.fullFiatText = viewModel.secondFieldEmptyStateFullFiatText
        view.secondAsset.sora.text = ""
        view.secondAsset.sora.assetImage = R.image.wallet.emptyToken()
        view.secondAsset.textField.inputAccessoryView = accessoryView
        view.secondAsset.sora.assetChoiceHandler = { [weak self] in
            self?.viewModel.choiсeTargetAssetButtonTapped()
        }
        view.secondAsset.textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.viewModel.focusedField = .two
        }
        view.secondAsset.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.reviewLiquidity.sora.isEnabled = false
            self?.viewModel.focusedField = .two
            self?.viewModel.inputedSecondAmount = Decimal(string: self?.assetsView.secondAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel.recalculate(field: .two)
        }
        return view
    }()
    
    private lazy var optionsView: OptionsView = {
        let view = OptionsView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.marketLabel.sora.isHidden = !viewModel.isSwap
        view.marketButton.sora.isHidden = !viewModel.isSwap
        view.slipageButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.changeSlippageTolerance()
        }
        view.marketButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.changeMarket()
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
            self?.viewModel.reviewButtonTapped()
        }
        return button
    }()
    
    private lazy var firstLiquidityWarningView: WarningView = {
        let view = WarningView()
        view.sora.isHidden = true
        return view
    }()

    var viewModel: LiquidityViewModelProtocol

    init(viewModel: LiquidityViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        addObservers()
        
        if let imageName = viewModel.imageName {
            let logo = UIImage(named: imageName)
            let imageView = UIImageView(image: logo)
            navigationItem.titleView = imageView
        }
        
        if let title = viewModel.title {
            navigationItem.title = title
        }

        addCloseButton()
        
        if !viewModel.isSwap {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: R.image.wallet.info24(),
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(infoTapped))
            navigationItem.leftBarButtonItem?.tintColor = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        }

        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
    }
    
    @objc
    func infoTapped() {
        viewModel.infoButtonTapped()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(containerView)

        containerView.addArrangedSubview(assetsView)
        containerView.addArrangedSubview(optionsView)
        containerView.addArrangedSubview(firstLiquidityWarningView)
        containerView.addArrangedSubview(warningView)
        containerView.addArrangedSubview(reviewLiquidity)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            
            assetsView.leadingAnchor.constraint(equalTo: containerView.stackView.leadingAnchor, constant: 16),
            assetsView.trailingAnchor.constraint(equalTo: containerView.stackView.trailingAnchor, constant: -16),
            
            warningView.leadingAnchor.constraint(equalTo: containerView.stackView.leadingAnchor, constant: 16),
            warningView.centerXAnchor.constraint(equalTo: containerView.stackView.centerXAnchor),
            
            firstLiquidityWarningView.leadingAnchor.constraint(equalTo: containerView.stackView.leadingAnchor, constant: 16),
            firstLiquidityWarningView.centerXAnchor.constraint(equalTo: containerView.stackView.centerXAnchor),

            reviewLiquidity.leadingAnchor.constraint(equalTo: containerView.stackView.leadingAnchor, constant: 16),
            reviewLiquidity.centerXAnchor.constraint(equalTo: containerView.stackView.centerXAnchor),
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
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    @objc
    private func keyboardWillShow(_ notification:Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            containerView.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: keyboardSize.height, right: 0)
        }
    }

    @objc
    private func keyboardWillHide(_ notification:Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            containerView.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)
        }
    }
}

extension PolkaswapViewController: LiquidityViewProtocol {
    func update(details: [DetailViewModel]) {
        containerView.stackView.arrangedSubviews.filter { $0 is DetailView || $0.tag == 1 }.forEach { subview in
            containerView.stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        
        let detailsViews = details.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.isHidden = detailModel.rewardAssetImage == nil
            
            if let image = detailModel.rewardAssetImage {
                view.assetImageView.sora.picture = .logo(image: image)
            }

            view.titleLabel.sora.text = detailModel.title
            view.valueLabel.sora.attributedText = detailModel.assetAmountText
            view.fiatValueLabel.sora.attributedText = detailModel.fiatAmountText
            view.fiatValueLabel.sora.isHidden = detailModel.fiatAmountText == nil
            view.infoButton.sora.isHidden = detailModel.infoHandler == nil
            view.infoButton.sora.addHandler(for: .touchUpInside) { [weak detailModel] in
                detailModel?.infoHandler?()
            }
            return view
        }
        
        detailsViews.forEach { detailView in
            containerView.addArrangedSubview(detailView)
            
            detailView.leadingAnchor.constraint(equalTo: containerView.stackView.leadingAnchor, constant: 16).isActive = true
            detailView.centerXAnchor.constraint(equalTo: containerView.stackView.centerXAnchor).isActive = true
        }
    }
    
    func updateFirstAsset(balance: String) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.fullFiatText = balance
        }
    }
    
    func updateSecondAsset(balance: String) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.fullFiatText = balance
        }
    }
    
    func updateFirstAsset(symbol: String, image: UIImage?) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.assetSymbol = symbol
            self.assetsView.firstAsset.sora.assetImage = image
        }
    }
    
    func updateSecondAsset(symbol: String, image: UIImage?) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.assetSymbol = symbol
            self.assetsView.secondAsset.sora.assetImage = image
        }
    }
    
    func updateFirstAsset(fiatText: String) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.inputedFiatAmountText = fiatText
        }
    }
    
    func updateSecondAsset(fiatText: String) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.inputedFiatAmountText = fiatText
        }
    }
    
    func update(slippageTolerance: String) {
        DispatchQueue.main.async {
            self.optionsView.slipageButton.sora.title = slippageTolerance
        }
    }
    
    func update(selectedMarket: String) {
        DispatchQueue.main.async {
            self.optionsView.marketButton.sora.title = selectedMarket
        }
    }
    
    func set(firstAmountText: String) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.textField.sora.text = firstAmountText == "0" ? "" : firstAmountText
        }
    }
    
    func set(secondAmountText: String) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.textField.sora.text = secondAmountText == "0" ? "" : secondAmountText
        }
    }
    
    func setupButton(isEnabled: Bool) {
        DispatchQueue.main.async {
            self.reviewLiquidity.sora.isEnabled = isEnabled
            if isEnabled {
                self.reviewLiquidity.sora.backgroundColor = .additionalPolkaswap
            }
        }
    }
    
    func focus(field: FocusedField) {
        DispatchQueue.main.async {
            if field == .one {
                self.assetsView.firstAsset.textField.becomeFirstResponder()
            } else {
                self.assetsView.secondAsset.textField.becomeFirstResponder()
            }
        }
        
    }
    
    func updateFirstAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.state = state
            self.assetsView.firstAsset.textField.sora.textColor = amountColor
            self.assetsView.firstAsset.inputedFiatAmountLabel.sora.textColor = fiatColor
        }
    }
    
    func updateSecondAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.state = state
            self.assetsView.secondAsset.textField.sora.textColor = amountColor
            self.assetsView.secondAsset.inputedFiatAmountLabel.sora.textColor = fiatColor
        }
    }
    
    func update(isNeedLoadingState: Bool) {
        DispatchQueue.main.async {
            self.reviewLiquidity.sora.loadingPlaceholder.type = isNeedLoadingState ? .shimmer : .none
        }
    }
    
    func updateMiddleButton(isEnabled: Bool) {
        DispatchQueue.main.async {
            self.assetsView.middleButton.sora.isEnabled = isEnabled
        }
    }
    
    func setupMarketButton(isLoadingState: Bool) {
        DispatchQueue.main.async {
            self.optionsView.marketButton.sora.loadingPlaceholder.type = isLoadingState ? .shimmer : .none
        }
        
    }
    
    func setAccessoryView(isHidden: Bool) {
        DispatchQueue.main.async {
            self.accessoryView.isHidden = isHidden
        }
    }

    func updateReviewButton(title: String) {
        DispatchQueue.main.async {
            self.reviewLiquidity.sora.title = title
        }
    }
    
    func updateWarinignView(model: WarningViewModel) {
        DispatchQueue.main.async {
            self.warningView.setupView(with: model)
        }
    }
    
    func updateFirstLiquidityWarinignView(model: WarningViewModel) {
        DispatchQueue.main.async {
            self.firstLiquidityWarningView.setupView(with: model)
        }
    }
}
