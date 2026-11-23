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

    private let segments = PortfolioSegmentedControl()

    var viewModel: SwitcherViewModel? {
        didSet {
            let buttons = viewModel?.buttonViewModels ?? []
            segments.configure(titles: buttons.map(\.title), selected: buttons.firstIndex(where: \.isSelected) ?? 0,
                               animated: window != nil && oldValue != nil)
        }
    }

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        sora.backgroundColor = .custom(uiColor: .clear)
        segments.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segments)
        NSLayoutConstraint.activate([
            segments.leadingAnchor.constraint(equalTo: leadingAnchor),
            segments.trailingAnchor.constraint(equalTo: trailingAnchor),
            segments.topAnchor.constraint(equalTo: topAnchor),
            segments.bottomAnchor.constraint(equalTo: bottomAnchor),
            segments.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
        segments.onSelect = { [weak self] index in
            guard let buttons = self?.viewModel?.buttonViewModels, buttons.indices.contains(index) else { return }
            buttons[index].actionBlock?()
        }
    }
}
