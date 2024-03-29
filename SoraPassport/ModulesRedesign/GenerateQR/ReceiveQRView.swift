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
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        return view
    }()
    
    private let qrImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        return imageView
    }()
    
    private lazy var accountContainerView: SoramitsuControl = {
        var view = SoramitsuControl()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
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
        label.sora.font = FontType.textS
        label.sora.numberOfLines = 2
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
            accountContainerView.heightAnchor.constraint(equalToConstant: 88),
            
            accountImageView.heightAnchor.constraint(equalToConstant: 40),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            accountImageView.centerYAnchor.constraint(equalTo: accountContainerView.centerYAnchor),
            accountImageView.leadingAnchor.constraint(equalTo: accountContainerView.leadingAnchor, constant: 16),
            
            mainStackView.leadingAnchor.constraint(equalTo: accountImageView.trailingAnchor, constant: 8),
            mainStackView.trailingAnchor.constraint(equalTo: accountContainerView.trailingAnchor, constant: -16),
            mainStackView.topAnchor.constraint(greaterThanOrEqualTo: accountContainerView.topAnchor, constant: 8),
            mainStackView.centerYAnchor.constraint(equalTo: accountContainerView.centerYAnchor),
            
            shareButton.topAnchor.constraint(equalTo: accountContainerView.bottomAnchor, constant: 15),
            shareButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            shareButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            shareButton.heightAnchor.constraint(equalToConstant: 56),
            
            scanQrButton.topAnchor.constraint(equalTo: shareButton.bottomAnchor, constant: 15),
            scanQrButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            scanQrButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            scanQrButton.heightAnchor.constraint(equalToConstant: 56),
            scanQrButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
