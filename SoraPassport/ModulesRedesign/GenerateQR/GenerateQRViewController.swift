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

protocol GenerateQRViewProtocol: ControllerBackedProtocol {}

final class GenerateQRViewController: SoramitsuViewController {

    private let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .center
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 0, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    private let scrollView: SoramitsuScrollView = {
        let scrollView = SoramitsuScrollView()
        scrollView.sora.keyboardDismissMode = .onDrag
        scrollView.sora.showsVerticalScrollIndicator = false
        scrollView.sora.cancelsTouchesOnDragging = true
        return scrollView
    }()
    
    private lazy var switcherView: SwitcherView = SwitcherView()
    
    private let inputSendInfoView: InputSendInfoView = {
        let view = InputSendInfoView()
        view.isHidden = true
        return view
    }()
    
    private var receiveView: ReceiveQRView = {
        let view = ReceiveQRView()
        view.isHidden = true
        return view
    }()

    var viewModel: GenerateQRViewModelProtocol

    init(viewModel: GenerateQRViewModelProtocol) {
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
        addCloseButton()

        navigationItem.title = R.string.localizable.receiveTokens(preferredLanguages: .currentLocale)

        viewModel.setupReceiveView = { [weak self] viewModel in
            DispatchQueue.main.async {
                self?.receiveView.viewModel = viewModel
            }
        }
        
        viewModel.setupSwicherView = { [weak self] viewModel in
            DispatchQueue.main.async {
                self?.switcherView.viewModel = viewModel
            }
        }
        
        viewModel.setupRequestView = { [weak self] viewModel in
            DispatchQueue.main.async {
                self?.inputSendInfoView.viewModel = viewModel
            }
        }

        viewModel.updateContent = { [weak self] mode in
            DispatchQueue.main.async {
                self?.receiveView.isHidden = mode == .request
                self?.inputSendInfoView.isHidden = mode == .receive
                
                if mode == .receive {
                    self?.view.endEditing(true)
                } else {
                    self?.inputSendInfoView.assetView.textField.becomeFirstResponder()
                }
            }
        }
        
        viewModel.showShareContent = { [weak self] sources in
            DispatchQueue.main.async {
                let activityController = UIActivityViewController(activityItems: sources, applicationActivities: nil)
                self?.present(activityController, animated: true, completion: nil)
            }
        }
        
        viewModel.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.closeHadler?()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)

        view.addSubviews(scrollView)
        scrollView.addSubview(stackView)
        
        stackView.addArrangedSubview(switcherView)
        stackView.addArrangedSubview(receiveView)
        stackView.addArrangedSubview(inputSendInfoView)
    }

    private func setupConstraints() {
        let scanQrButtonTopOffset: CGFloat = 16
        let scanQrButtonHeight: CGFloat = 56
        
        NSLayoutConstraint.activate([
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                               constant: -scanQrButtonHeight - scanQrButtonTopOffset),
            
            inputSendInfoView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 24),
            inputSendInfoView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            receiveView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            receiveView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            switcherView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}

extension GenerateQRViewController: GenerateQRViewProtocol {}
