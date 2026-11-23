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

protocol GenerateQRViewProtocol: ControllerBackedProtocol {
    func didCopyAddress(_ address: String)
}

extension GenerateQRViewProtocol {
    func didCopyAddress(_ address: String) {}
}

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

    private var mode = GenerateQRMode.receive
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
                self?.receiveView.isHidden = self?.mode == .request
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
                self?.mode = mode
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
                guard let self else { return }
                activityController.popoverPresentationController?.sourceView = self.receiveView.shareButton
                activityController.popoverPresentationController?.sourceRect = self.receiveView.shareButton.bounds
                self.present(activityController, animated: true)
            }
        }
        
        viewModel.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        var owner: UIViewController? = self
        while let current = owner {
            if current.isBeingDismissed || current.isMovingFromParent {
                let close = viewModel.closeHadler
                if let coordinator = transitionCoordinator {
                    coordinator.animate(alongsideTransition: nil) { context in
                        if !context.isCancelled { close?() }
                    }
                } else {
                    close?()
                }
                return
            }
            owner = current.parent
        }
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
        NSLayoutConstraint.activate([
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            
            switcherView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        // The same places on a phone; a readable column in the middle of a wider window.
        WalletDisplay.pinReadable(inputSendInfoView, width: stackView.widthAnchor,
                                  centerX: stackView.centerXAnchor, margin: 24)
        WalletDisplay.pinReadable(receiveView, width: view.widthAnchor, centerX: view.centerXAnchor, margin: 24)
    }
}

extension GenerateQRViewController: GenerateQRViewProtocol {
    func didCopyAddress(_ address: String) {
        receiveView.addressCopied(address)
    }
}
