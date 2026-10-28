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
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
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


