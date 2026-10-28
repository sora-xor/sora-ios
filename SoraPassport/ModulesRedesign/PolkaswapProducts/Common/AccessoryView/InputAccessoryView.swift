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
import SoraUIKit
import UIKit

struct InputAccessoryVariant {
    let displayValue: String
    let value: Decimal
}

protocol InputAccessoryViewDelegate: AnyObject {
    func didSelect(variant: Decimal)
}

final class InputAccessoryView: SoramitsuView {
    
    weak var delegate: InputAccessoryViewDelegate?

    public var variants: [InputAccessoryVariant] = [] {
        didSet {
            stackView.arrangedSubviews.forEach {
                stackView.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }
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
                    separatorView.sora.backgroundColor = .fgOutline
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
        sora.backgroundColor = .bgSurface
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
