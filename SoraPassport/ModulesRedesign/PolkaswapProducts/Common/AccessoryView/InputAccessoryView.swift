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
import SoraUIKit
import UIKit

struct InputAccessoryVariant {
    let displayValue: String
    let value: Float
}

protocol InputAccessoryViewDelegate: AnyObject {
    func didSelect(variant: Float)
}

final class InputAccessoryView: SoramitsuView {
    
    weak var delegate: InputAccessoryViewDelegate?

    public var variants: [InputAccessoryVariant] = [] {
        didSet {
            variants.enumerated().forEach { (index, variant) in
                let button = SoramitsuButton()
                button.translatesAutoresizingMaskIntoConstraints = false
                button.sora.backgroundColor = .custom(uiColor: .clear)
                button.sora.horizontalOffset = 10
                button.sora.attributedText = SoramitsuTextItem(text: variant.displayValue,
                                                               fontData: FontType.paragraphL,
                                                               textColor: .fgPrimary,
                                                               alignment: .center)
                button.sora.addHandler(for: .touchUpInside) { [weak self] in
                    self?.delegate?.didSelect(variant: variant.value)
                }
                stackView.addArrangedSubviews(button)
                
                if index != variants.count - 1 {
                    let separatorView = SoramitsuView()
                    separatorView.widthAnchor.constraint(equalToConstant: 1).isActive = true
                    separatorView.heightAnchor.constraint(equalToConstant: 25).isActive = true
                    separatorView.sora.backgroundColor = .custom(uiColor: UIColor(hex: "#b1b5bb"))
                    stackView.addArrangedSubview(separatorView)
                }
            }
        }
    }
    let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.sora.distribution = .fillProportionally
        view.clipsToBounds = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: UIColor(hex: "#d3d1d8"))
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
}
