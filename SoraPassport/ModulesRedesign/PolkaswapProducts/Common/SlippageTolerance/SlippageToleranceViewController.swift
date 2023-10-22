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

protocol SlippageToleranceViewProtocol: ControllerBackedProtocol {
    func setup(tolerance: Float)
    func setupDoneButton(isEnabled: Bool)
}

final class SlippageToleranceViewController: SoramitsuViewController {

    private lazy var accessoryView: InputAccessoryView = {
        let rect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 48))
        let view = InputAccessoryView(frame: rect)
        view.delegate = viewModel
        view.variants = [ InputAccessoryVariant(displayValue: "0.1%", value: 0.1),
                          InputAccessoryVariant(displayValue: "0.5%", value: 0.5),
                          InputAccessoryVariant(displayValue: "1%", value: 1) ]
        return view
    }()
    
    private lazy var slippageToleranceView: SlippageToleranceView = {
        let view = SlippageToleranceView()
        view.delegate = viewModel
        view.slipageButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.doneButtonTapped()
        }
        view.field.textField.inputAccessoryView = accessoryView
        return view
    }()

    var viewModel: SlippageToleranceViewModelProtocol

    init(viewModel: SlippageToleranceViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.backButtonTitle = ""
        navigationItem.title = R.string.localizable.polkaswapSlippageTolerance(preferredLanguages: .currentLocale)
        setupView()
        setupConstraints()
        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        slippageToleranceView.field.textField.becomeFirstResponder()
    }

    @objc
    func closeTapped() {
        self.dismiss(animated: true)
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(slippageToleranceView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            slippageToleranceView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            slippageToleranceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            slippageToleranceView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}

extension SlippageToleranceViewController: SlippageToleranceViewProtocol {
    func setupDoneButton(isEnabled: Bool) {
        slippageToleranceView.slipageButton.sora.isEnabled = isEnabled
        if isEnabled {
            slippageToleranceView.slipageButton.sora.backgroundColor = .additionalPolkaswap
        }
    }
    
    func setup(tolerance: Float) {
        slippageToleranceView.field.sora.text = "\(tolerance)%"
    }
}


