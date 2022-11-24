/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
