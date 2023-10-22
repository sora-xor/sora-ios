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

protocol ChoiceMarketViewProtocol: ControllerBackedProtocol {
    func setup(markets: [LiquiditySourceType])
    func setup(selectedMarket: LiquiditySourceType)
}

final class ChoiceMarketViewController: SoramitsuViewController {
    
    private lazy var stackView: SoramitsuStackView = {
        let view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    var viewModel: ChoiceMarketViewModelProtocol

    init(viewModel: ChoiceMarketViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.backButtonTitle = ""
        navigationItem.title = R.string.localizable.polkaswapMarketTitle(preferredLanguages: .currentLocale)
        setupView()
        setupConstraints()
        viewModel.viewDidLoad()
    }

    @objc
    func closeTapped() {
        self.dismiss(animated: true)
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(stackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    private func showAlert(title: String, message: String) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let useAction = UIAlertAction(
            title: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            style: .default) { (_: UIAlertAction) -> Void in
        }
        alertView.addAction(useAction)

        present(alertView, animated: true)
    }
}

extension ChoiceMarketViewController: ChoiceMarketViewProtocol {
    func setup(markets: [LiquiditySourceType]) {
        markets.forEach { market in
            let marketView = MarketView(type: market)
            marketView.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.viewModel.selectedMarket = market
            }
            marketView.infoButton.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.showAlert(title: market.titleForLocale(.current), message: market.descriptionText ?? "")
            }
            stackView.addArrangedSubview(marketView)
        }
    }
    
    func setup(selectedMarket: LiquiditySourceType) {
        stackView.arrangedSubviews.forEach {
            guard let view = $0 as? MarketView else { return }
            view.isSelectedMarket = view.type == selectedMarket
        }
    }
}


