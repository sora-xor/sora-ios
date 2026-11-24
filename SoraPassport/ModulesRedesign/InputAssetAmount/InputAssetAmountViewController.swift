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
import SSFUtils
import UIKit

protocol InputAssetAmountViewProtocol: ControllerBackedProtocol, Warningable {
    func updateFirstAsset(balance: String)
    func updateFirstAsset(symbol: String, image: UIImage?)
    func updateFirstAsset(fiatText: String)
    func updateRecipientView(with address: String)
    func updateFirstAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor)
    func set(firstAmountText: String)
    func setupButton(isEnabled: Bool)
    func focusFirstField()
}

final class InputAssetAmountViewController: SoramitsuViewController {
    
    private let generator = PolkadotIconGenerator()

    /// The screen's content column: the recipient, the amount, a warning and Review fill it.
    private let stackView: LitColumnStackView = {
        let stackView = LitColumnStackView()
        stackView.backgroundColor = .clear
        stackView.spacing = 24
        stackView.topInset = 16
        stackView.bottomInset = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var scrollView: SoramitsuScrollView = {
        let scrollView = SoramitsuScrollView()
        scrollView.sora.keyboardDismissMode = .onDrag
        scrollView.sora.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        return scrollView
    }()
    
    public lazy var recipientView: RecipientAddressView = {
        let view = RecipientAddressView()
        view.contactView.button.isHidden = false
        view.contactView.onTap = { [weak self] in
            self?.viewModel.selectAddress()
        }
        return view
    }()
    
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
    
    public lazy var assetView: InputAssetField = {
        let field = InputAssetField()
        field.sora.assetArrow = R.image.wallet.arrow()
        field.sora.assetImage = PortfolioGlyphs.emptyTokenImage()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        field.textField.inputAccessoryView = accessoryView
        field.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.viewModel.inputedFirstAmount = Decimal.parseLocalizedAmount(field.textField.text ?? "", locale: Locale.current) ?? 0
        }
        field.sora.assetChoiceHandler = { [weak self] in
            self?.viewModel.choiceBaseAssetButtonTapped()
        }
        return field
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
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.reviewButtonTapped()
        }
        return button
    }()

    var viewModel: InputAssetAmountViewModelProtocol

    init(viewModel: InputAssetAmountViewModelProtocol) {
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
        
        navigationItem.title = R.string.localizable.commonEnterAmount(preferredLanguages: .currentLocale)
        
        addCloseButton()

        viewModel.viewDidLoad()
    }
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubviews(scrollView)
        scrollView.addSubview(stackView)
        
        stackView.addArrangedSubview(recipientView)
        stackView.addArrangedSubview(assetView)
        stackView.addArrangedSubview(warningView)
        stackView.addArrangedSubview(reviewLiquidity)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            // The form ends where the keyboard begins, so Review can be scrolled into view above it. A
            // spacer most of a screen tall once stood in for this, and the form scrolled away with no
            // keyboard up.
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
    }
}

extension InputAssetAmountViewController: InputAssetAmountViewProtocol {
    
    func updateFirstAsset(balance: String) {
        assetView.sora.fullFiatText = balance
        // The balance is a button: all of it, less the fee when the token pays fees.
        if assetView.sora.balanceTapHandler == nil {
            assetView.sora.balanceTapHandler = { [weak self] in self?.viewModel.didSelect(variant: 1) }
        }
    }
    
    func updateFirstAsset(symbol: String, image: UIImage?) {
        assetView.sora.assetSymbol = symbol
        assetView.sora.assetImage = image
    }
    
    func updateFirstAsset(fiatText: String) {
        assetView.sora.inputedFiatAmountText = fiatText
    }
    
    func set(firstAmountText: String) {
        DispatchQueue.main.async {
            self.assetView.textField.sora.text = firstAmountText == "0" ? "" : firstAmountText
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
    
    func focusFirstField() {
        assetView.textField.becomeFirstResponder()
    }
    
    func updateFirstAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor) {
        DispatchQueue.main.async {
            self.assetView.sora.state = state
            self.assetView.textField.sora.textColor = amountColor
            self.assetView.inputedFiatAmountLabel.sora.textColor = fiatColor
        }
    }
    
    func updateRecipientView(with address: String) {
        recipientView.contactView.accountTitle.sora.text = address.isEmpty
            ? R.string.localizable.selectRecipient(preferredLanguages: .currentLocale) : address
        recipientView.contactView.accountImageView.image = address.isEmpty
            ? UIImage(systemName: "person.crop.circle") : try? generator.generateFromAddress(address)
            .imageWithFillColor(UIColor.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
    }
    
    func updateWarinignView(model: WarningViewModel) {
        DispatchQueue.main.async {
            self.warningView.setupView(with: model)
        }
    }
}
