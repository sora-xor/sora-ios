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
import FearlessUtils
import Combine

final class InputSendInfoView: SoramitsuView {
    
    private let generator = PolkadotIconGenerator()
    private var cancellables: Set<AnyCancellable> = []
    private let input: PassthroughSubject<InputSendInfoViewModel.Input, Never> = .init()
    
    var viewModel: InputSendInfoViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            let output = viewModel.transform(input: input.eraseToAnyPublisher())
            output
                .receive(on: DispatchQueue.main)
                .sink { event in }
                .store(in: &cancellables)
            
            viewModel.$balanceFiatText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.assetView.sora.fullFiatText = viewModel.balanceFiatText
                }
                .store(in: &cancellables)
            
            viewModel.$assetSymbol
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.assetView.sora.assetSymbol = viewModel.assetSymbol
                }
                .store(in: &cancellables)
            
            viewModel.$assetImage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.assetView.sora.assetImage = viewModel.assetImage
                }
                .store(in: &cancellables)
            
            viewModel.$inputedFiatAmountText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.assetView.sora.inputedFiatAmountText = viewModel.inputedFiatAmountText
                }
                .store(in: &cancellables)
            
            viewModel.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.assetView.sora.state = viewModel.state ?? .default
                }
                .store(in: &cancellables)
            
            viewModel.$address
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.recipientView.contactView.accountTitle.sora.text = viewModel.address
                    self.recipientView.contactView.accountImageView.image = try? self.generator.generateFromAddress(viewModel.address ?? "")
                        .imageWithFillColor(.white,
                                            size: CGSize(width: 40.0, height: 40.0),
                                            contentScale: UIScreen.main.scale)
                }
                .store(in: &cancellables)
            
            viewModel.$username
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.recipientView.contactView.usernameTitle.sora.text = viewModel.username
                    self.recipientView.contactView.usernameTitle.sora.isHidden = viewModel.username?.isEmpty ?? true
                }
                .store(in: &cancellables)

        }
    }
    
    private let mainStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 24
        return mainStackView
    }()
    
    public lazy var recipientView: RecipientAddressView = {
        let view = RecipientAddressView()
        view.contactView.button.isHidden = true
        view.contactView.arrowImageView.alpha = 0
        return view
    }()
    
    public lazy var assetView: InputAssetField = {
        let field = InputAssetField()
        field.sora.assetArrow = R.image.wallet.arrow()
        field.sora.assetImage = R.image.wallet.emptyToken()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.textField.sora.textColor = .fgPrimary
        field.inputedFiatAmountLabel.sora.textColor = .fgSecondary
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        field.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            if let typedText = field.textField.text {
                var dotCount = 0
                for c in typedText {
                    if String(c) == "." || String(c) == "," {  dotCount += 1  }
                }
                if dotCount >= 2 {
                    field.textField.sora.text = String(typedText.dropLast())
                }
            }
            let currentAmount = field.textField.text?.replacingOccurrences(of: ",", with: ".") ?? ""
            self?.viewModel?.inputedAmount = Decimal(string: currentAmount) ?? 0
        }
        field.sora.assetChoiceHandler = { [weak self] in
            self?.input.send(.choiseAsset)
        }
        return field
    }()
    
    private lazy var reviewLiquidity: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.title = R.string.localizable.commonCreateQrRequest(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.input.send(.createQr)
        }
        return button
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }
    
    private func setupSubviews() {
        translatesAutoresizingMaskIntoConstraints = false
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubview(mainStackView)
        mainStackView.addArrangedSubviews(recipientView, assetView, reviewLiquidity)
    }
    
    private func setupConstrains() {
        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
