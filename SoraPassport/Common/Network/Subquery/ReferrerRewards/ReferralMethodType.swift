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

enum ReferralMethodType: String {
    case bond = "reserve"
    case unbond = "unreserve"
    case setReferrer = "setReferrer"
    case setReferral = "setReferral"

    var title: String {
        switch self {
        case .bond: return R.string.localizable.historyReferralBondTokens(preferredLanguages: .currentLocale)
        case .unbond: return R.string.localizable.historyReferralUnbondTokens(preferredLanguages: .currentLocale)
        case .setReferrer: return R.string.localizable.historyReferralSetReferrer(preferredLanguages: .currentLocale)
        case .setReferral: return R.string.localizable.historyReferralSetReferral(preferredLanguages: .currentLocale)
        }
    }

    var detailText: String {
        switch self {
        case .bond: return R.string.localizable.historyBondedTokens(preferredLanguages: .currentLocale).uppercased()
        case .unbond: return R.string.localizable.historyUnbondedTokens(preferredLanguages: .currentLocale).uppercased()
        case .setReferrer: return R.string.localizable.historyReferralSetReferrer(preferredLanguages: .currentLocale).uppercased()
        case .setReferral: return  R.string.localizable.historyReferralSetReferral(preferredLanguages: .currentLocale).uppercased()
        }
    }

    init(fromRawValue: String) {
        self = ReferralMethodType(rawValue: fromRawValue) ?? .bond
    }
}
