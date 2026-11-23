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
        view.stackView.topInset = 16
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
        view.firstAsset.sora.assetImage = PortfolioGlyphs.emptyTokenImage()
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
            self?.viewModel.inputedFirstAmount = Decimal.parseLocalizedAmount(self?.assetsView.firstAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel.recalculate(field: .one)
        }
        
        view.secondAsset.sora.assetSymbol = R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
        view.secondAsset.sora.fullFiatText = viewModel.secondFieldEmptyStateFullFiatText
        view.secondAsset.sora.text = ""
        view.secondAsset.sora.assetImage = PortfolioGlyphs.emptyTokenImage()
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
            self?.viewModel.inputedSecondAmount = Decimal.parseLocalizedAmount(self?.assetsView.secondAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel.recalculate(field: .two)
        }
        return view
    }()
    
    private lazy var optionsView: OptionsView = {
        let view = OptionsView()
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
        button.sora.horizontalOffset = LayoutCanvas.pageMargin
        button.sora.title = R.string.localizable.review(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        // The one screen-level CTA here: static glow, no pulse (spec §4.5).
        button.sora.glows = true
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
        
        updateNavigationLogo()
        SoramitsuUI.updates.addObserver(self)
        
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

    private func updateNavigationLogo() {
        guard let imageName = viewModel.imageName else { return }
        if imageName.lowercased().contains("polkaswap") {
            // The flower in SORA red and the name in ink: the brand asset's pink flower is not the app's colour.
            if !(navigationItem.titleView is PolkaswapTitleView) { navigationItem.titleView = PolkaswapTitleView() }
            return
        }
        // The app appearance can differ from the system's trait collection.
        // Resolve the brand asset against the chosen app theme explicitly.
        let traits = UITraitCollection(userInterfaceStyle: SoramitsuUI.shared.theme == .dark ? .dark : .light)
        let logo = UIImage(named: imageName, in: nil, compatibleWith: traits)
        if let imageView = navigationItem.titleView as? UIImageView {
            imageView.image = logo
        } else {
            navigationItem.titleView = UIImageView(image: logo)
        }
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

        // The cards, the warnings and Review fill the column; the two option pads stay their own size
        // in the middle of their row.
        containerView.addArrangedSubview(assetsView)
        containerView.addArrangedSubview(LitColumnStackView.centred(optionsView))
        containerView.addArrangedSubview(firstLiquidityWarningView)
        containerView.addArrangedSubview(warningView)
        containerView.addArrangedSubview(reviewLiquidity)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
    }

    private func rotateAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let button = assetsView.middleButton
        // The pad turns half over on a spring, and the two cards pass each other for a moment.
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.6,
                       options: [.allowUserInteraction]) {
            button.transform = button.transform.rotated(by: .pi)
        }
        let first = assetsView.firstAsset
        let second = assetsView.secondAsset
        let shift = max(0, second.frame.minY - first.frame.minY) * 0.22
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
            first.transform = CGAffineTransform(translationX: 0, y: shift).scaledBy(x: 0.97, y: 0.97)
            second.transform = CGAffineTransform(translationX: 0, y: -shift).scaledBy(x: 0.97, y: 0.97)
            first.alpha = 0.55
            second.alpha = 0.55
        } completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0,
                           options: [.allowUserInteraction]) {
                first.transform = .identity
                second.transform = .identity
                first.alpha = 1
                second.alpha = 1
            }
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
        guard let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        // Only what the keyboard covers of this screen: a floating or split keyboard on an iPad covers
        // less than its own height, or nothing.
        let covered = view.convert(frame, from: nil).intersection(view.bounds)
        containerView.stackView.bottomInset = covered.isNull ? 0 : covered.height
    }

    @objc
    private func keyboardWillHide(_ notification:Notification) {
        guard notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] is NSValue else { return }
        containerView.stackView.bottomInset = 0
    }
}

extension PolkaswapViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        updateNavigationLogo()
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
        }
    }
    
    func updateFirstAsset(balance: String) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.fullFiatText = balance
            if self.assetsView.firstAsset.sora.balanceTapHandler == nil {
                self.assetsView.firstAsset.sora.balanceTapHandler = { [weak self] in self?.useWholeBalance(of: .one) }
            }
        }
    }
    
    func updateSecondAsset(balance: String) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.fullFiatText = balance
            // In a swap the second card is what you get: all of its balance means nothing there.
            if !self.viewModel.isSwap, self.assetsView.secondAsset.sora.balanceTapHandler == nil {
                self.assetsView.secondAsset.sora.balanceTapHandler = { [weak self] in self?.useWholeBalance(of: .two) }
            }
        }
    }

    /// The balance under a token is a button: all of it, less the fee when the token pays fees.
    private func useWholeBalance(of field: FocusedField) {
        viewModel.focusedField = field
        viewModel.didSelect(variant: 1)
        viewModel.recalculate(field: field)
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

/// The Polkaswap flower in SORA red beside the name, for the navigation bar of the Polkaswap screens.
final class PolkaswapTitleView: UIStackView {
    init() {
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .center
        spacing = 6
        let flower = UIImageView(image: PortfolioGlyphs.flowerImage(size: 20))
        flower.widthAnchor.constraint(equalToConstant: 20).isActive = true
        flower.heightAnchor.constraint(equalToConstant: 20).isActive = true
        let name = UILabel()
        name.text = "Polkaswap"
        name.font = .systemFont(ofSize: 17, weight: .semibold)
        name.textColor = SoramitsuUI.shared.theme.palette.color(.fgPrimary)
        addArrangedSubview(flower)
        addArrangedSubview(name)
        isAccessibilityElement = true
        accessibilityLabel = "Polkaswap"
        accessibilityTraits = .header
        // A slow turn of the flower when the screen opens.
        if !UIAccessibility.isReduceMotionEnabled {
            let turn = CABasicAnimation(keyPath: "transform.rotation.z")
            turn.fromValue = -CGFloat.pi / 3
            turn.toValue = 0
            turn.duration = 0.9
            turn.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            flower.layer.add(turn, forKey: "turn")
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
