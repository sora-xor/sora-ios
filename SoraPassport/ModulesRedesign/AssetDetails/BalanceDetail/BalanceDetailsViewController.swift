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

final class BalanceDetailsViewController: SoramitsuViewController {

    private let swipeView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .fgTertiary
        view.sora.cornerRadius = .circle
        return view
    }()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 0
        return view
    }()
    

    var viewModels: [BalanceDetailViewModel]

    init(viewModels: [BalanceDetailViewModel]) {
        self.viewModels = viewModels
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        
        for (index, model) in viewModels.enumerated() {
            let view = BalanceDetailView()
            view.viewModel = model
            view.heightAnchor.constraint(equalToConstant: 48).isActive = true
            stackView.addArrangedSubview(view)
            
            if index != viewModels.count - 1 {
                let view = SoramitsuView()
                view.heightAnchor.constraint(equalToConstant: 24).isActive = true
                
                if index != 0 {
                    let separatorView = SoramitsuView()
                    separatorView.sora.backgroundColor = .fgOutline
                    view.addSubview(separatorView)
                    separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                    separatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
                    separatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                    separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
                }

                stackView.addArrangedSubview(view)
            }
        }
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubviews(stackView, swipeView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            swipeView.widthAnchor.constraint(equalToConstant: 32),
            swipeView.heightAnchor.constraint(equalToConstant: 4),
            swipeView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            swipeView.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -8),
            
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }
}
