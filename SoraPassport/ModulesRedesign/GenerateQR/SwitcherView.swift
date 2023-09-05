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

class SwitcherButtonViewModel {
    let title: String
    var isSelected: Bool
    var actionBlock: (() -> Void)?
    
    init(title: String, isSelected: Bool, actionBlock: (() -> Void)? = nil) {
        self.title = title
        self.isSelected = isSelected
        self.actionBlock = actionBlock
    }
}

struct SwitcherViewModel {
    let buttonViewModels: [SwitcherButtonViewModel]
}

final class SwitcherView: SoramitsuView {

    var viewModel: SwitcherViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            
            mainStackView.arrangedSubviews.forEach { subview in
                mainStackView.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }

            let butttonViews = viewModel.buttonViewModels.map { buttonViewModel -> SoramitsuButton in
                let title = SoramitsuTextItem(text:  buttonViewModel.title,
                                              fontData: FontType.textBoldS,
                                              textColor: buttonViewModel.isSelected ? .bgSurface : .accentSecondary,
                                              alignment: .center)
                let button = SoramitsuButton()
                button.sora.attributedText = title
                button.sora.cornerRadius = .circle
                button.sora.backgroundColor = buttonViewModel.isSelected ? .accentSecondary : .bgSurfaceVariant
                button.sora.horizontalOffset = 12
                button.sora.addHandler(for: .touchUpInside) {
                    buttonViewModel.actionBlock?()
                }
                return button
            }

            mainStackView.addArrangedSubviews(butttonViews)
        }
    }
    
    private let mainStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .horizontal
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 8
        return mainStackView
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
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            mainStackView.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
}
