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
}

final class ReceiveQRView: SoramitsuView {
    
    private let generator = PolkadotIconGenerator()
    
    var viewModel: ReceiveQRViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            accountAddress.sora.text = viewModel.address
            accountContainerView.accessibilityLabel = [viewModel.name, viewModel.address].filter { !$0.isEmpty }.joined(separator: ", ")
            accountImageView.image = try? generator.generateFromAddress(viewModel.address)
                .imageWithFillColor(UIColor.white,
                                    size: CGSize(width: 40.0, height: 40.0),
                                    contentScale: UIScreen.main.scale)
            
            qrImageView.image = viewModel.qrImage
            accountTitle.sora.text = viewModel.name
            accountTitle.sora.isHidden = viewModel.name.isEmpty
            isHidden = false
        }
    }

    private let qrContainerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .custom(uiColor: .white)
        view.sora.material = .solid
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.semanticContentAttribute = .forceLeftToRight
        return view
    }()
    
    private let qrImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.minificationFilter = .nearest
        imageView.isAccessibilityElement = false
        return imageView
    }()
    
    private lazy var accountContainerView: SoramitsuControl = {
        var view = SoramitsuControl()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel?.accountTapHandler?()
        }
        return view
    }()
    
    private let accountImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private let mainStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.distribution = .equalSpacing
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 0
        mainStackView.isUserInteractionEnabled = false
        return mainStackView
    }()
    
    private let accountTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.isHidden = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private let accountAddress: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.mono
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byCharWrapping
        label.semanticContentAttribute = .forceLeftToRight
        label.isUserInteractionEnabled = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()
    
    private lazy var shareButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.tintColor = .fgInverted
        button.sora.leftImage = R.image.wallet.send()
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonShare(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .bgSurface,
                                                       alignment: .center)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentSecondary
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel?.shareHandler?()
        }
        return button
    }()
    
    private lazy var scanQrButton: SoramitsuButton = {
        let text = SoramitsuTextItem(
            text: R.string.localizable.commomScanQr(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .accentSecondary,
            alignment: .center
        )
        
        let button = SoramitsuButton()
        button.sora.attributedText = text
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .bgSurface
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel?.scanQRHandler?()
        }
        return button
    }()

    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .custom(uiColor: .clear)
        
        qrContainerView.addSubview(qrImageView)
        
        mainStackView.addArrangedSubviews(accountTitle, accountAddress)
        
        accountContainerView.addSubview(accountImageView)
        accountContainerView.addSubviews(mainStackView)
        
        addSubview(qrContainerView)
        addSubview(accountContainerView)
        addSubview(shareButton)
        addSubview(scanQrButton)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            qrContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            qrContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            qrContainerView.heightAnchor.constraint(equalTo: qrContainerView.widthAnchor),
            qrContainerView.topAnchor.constraint(equalTo: topAnchor),
            
            qrImageView.leadingAnchor.constraint(equalTo: qrContainerView.leadingAnchor, constant: 24),
            qrImageView.centerXAnchor.constraint(equalTo: qrContainerView.centerXAnchor),
            qrImageView.centerYAnchor.constraint(equalTo: qrContainerView.centerYAnchor),
            qrImageView.topAnchor.constraint(equalTo: qrContainerView.topAnchor, constant: 24),
            
            accountContainerView.topAnchor.constraint(equalTo: qrContainerView.bottomAnchor, constant: 16),
            accountContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            accountContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            accountContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
            
            accountImageView.heightAnchor.constraint(equalToConstant: 40),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            accountImageView.centerYAnchor.constraint(equalTo: accountContainerView.centerYAnchor),
            accountImageView.leadingAnchor.constraint(equalTo: accountContainerView.leadingAnchor, constant: 16),
            
            mainStackView.leadingAnchor.constraint(equalTo: accountImageView.trailingAnchor, constant: 8),
            mainStackView.trailingAnchor.constraint(equalTo: accountContainerView.trailingAnchor, constant: -16),
            mainStackView.topAnchor.constraint(equalTo: accountContainerView.topAnchor, constant: 16),
            mainStackView.centerYAnchor.constraint(equalTo: accountContainerView.centerYAnchor),
            
            shareButton.topAnchor.constraint(equalTo: accountContainerView.bottomAnchor, constant: 15),
            shareButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            shareButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            shareButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            
            scanQrButton.topAnchor.constraint(equalTo: shareButton.bottomAnchor, constant: 15),
            scanQrButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            scanQrButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            scanQrButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            scanQrButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
