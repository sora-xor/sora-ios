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
import Anchorage

enum FrozenDetailType: Int, CaseIterable {
    case frozen = 0
    case locked
    case bonded
    case reserved
    case redeemable
    case unbonding
    
    var title: String {
        switch self {
        case .frozen: return R.string.localizable.detailsFrozen(preferredLanguages: .currentLocale)
        case .locked: return R.string.localizable.walletBalanceLocked(preferredLanguages: .currentLocale)
        case .bonded: return R.string.localizable.walletBonded(preferredLanguages: .currentLocale)
        case .reserved: return R.string.localizable.walletBalanceReserved(preferredLanguages: .currentLocale)
        case .redeemable: return R.string.localizable.walletRedeemable(preferredLanguages: .currentLocale)
        case .unbonding: return R.string.localizable.walletUnbonding(preferredLanguages: .currentLocale)
        }
    }
}

enum BalanceDetailType {
    case header
    case body
    
    var titleColor: SoramitsuColor {
        return self == .header ? .fgPrimary : .fgSecondary
    }
    
    var titleFont: FontData {
        return self == .header ? FontType.headline2 : FontType.textBoldXS
    }
    
    var amountFont: FontData {
        return self == .header ? FontType.headline2 : FontType.textM
    }
    
    var fiatAmountFont: FontData {
        return self == .header ? FontType.headline3 : FontType.textBoldXS
    }
}

struct BalanceDetailViewModel {
    let title: SoramitsuTextItem
    let amount: SoramitsuTextItem
    let fiatAmount: SoramitsuTextItem
}

final class BalanceDetailView: SoramitsuView {
    
    var viewModel: BalanceDetailViewModel? {
        didSet {
            titleLabel.sora.attributedText = viewModel?.title
            amountLabel.sora.attributedText = viewModel?.amount
            fiatAmountLabel.sora.attributedText = viewModel?.fiatAmount
        }
    }

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.sora.alignment  = .left
        return label
    }()
    
    let amountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.sora.alignment = .right
        return label
    }()
    
    let fiatAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .custom(uiColor: .clear)
        translatesAutoresizingMaskIntoConstraints = false

        addSubviews(titleLabel, amountLabel, fiatAmountLabel)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor),
            
            amountLabel.topAnchor.constraint(equalTo: topAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            
            fiatAmountLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 4),
            fiatAmountLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            fiatAmountLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            fiatAmountLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
        ])
    }
}
