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

enum InputRewardAmountType: String {
    case bond
    case unbond

    var screenTitle: String {
        switch self {
        case .bond: return R.string.localizable.referralAddInvitationsTitle(preferredLanguages: .currentLocale)
        case .unbond: return R.string.localizable.referralUnbondButtonTitle(preferredLanguages: .currentLocale)
        }
    }

    var title: String? {
        switch self {
        case .bond: return R.string.localizable.referralInputRewardTitle(preferredLanguages: .currentLocale)
        case .unbond: return nil
        }
    }

    func descriptionText(with fee: String) -> String {
        switch self {
        case .bond: return R.string.localizable.referralInputRewardDescription(fee)
        case .unbond: return R.string.localizable.referralUnbondXorDescription(fee)
        }
    }

    var buttonTitle: String {
        switch self {
        case .bond: return R.string.localizable.referralBondButtonTitle(preferredLanguages: .currentLocale)
        case .unbond: return R.string.localizable.referralUnbondButtonTitle(preferredLanguages: .currentLocale)
        }
    }
}
