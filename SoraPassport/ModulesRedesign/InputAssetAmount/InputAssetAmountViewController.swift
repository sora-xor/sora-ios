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
import FearlessUtils

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
    private var spaceConstraint: NSLayoutConstraint?
    
    private let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .center
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    private let scrollView: SoramitsuScrollView = {
        let scrollView = SoramitsuScrollView()
        scrollView.sora.keyboardDismissMode = .onDrag
        scrollView.sora.showsVerticalScrollIndicator = false
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
        field.sora.assetImage = R.image.wallet.emptyToken()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        field.textField.inputAccessoryView = accessoryView
        field.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.viewModel.inputedFirstAmount = Decimal(string: field.textField.text ?? "", locale: Locale.current) ?? 0
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
        button.sora.horizontalOffset = 0
        button.sora.title = R.string.localizable.review(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        spaceConstraint?.constant = UIScreen.main.bounds.height - 300
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubviews(scrollView)
        scrollView.addSubview(stackView)
        
        stackView.addArrangedSubview(recipientView)
        stackView.addArrangedSubview(assetView)
        stackView.addArrangedSubview(warningView)
        stackView.addArrangedSubview(reviewLiquidity)
        let spaceView = SoramitsuView()
        spaceConstraint = spaceView.heightAnchor.constraint(equalToConstant: 0)
        spaceConstraint?.isActive = true
        stackView.addArrangedSubviews(spaceView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.heightAnchor.constraint(equalTo: view.heightAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            
            recipientView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            recipientView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            assetView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            assetView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            warningView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            warningView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            reviewLiquidity.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            reviewLiquidity.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
        ])
    }
}

extension InputAssetAmountViewController: InputAssetAmountViewProtocol {
    
    func updateFirstAsset(balance: String) {
        assetView.sora.fullFiatText = balance
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
        recipientView.contactView.accountTitle.sora.text = address
        recipientView.contactView.accountImageView.image = try? generator.generateFromAddress(address)
            .imageWithFillColor(.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
    }
    
    func updateWarinignView(model: WarningViewModel) {
//        warningView.setupView(with: model)
    }
}
