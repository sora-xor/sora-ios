enum InputRewardAmountType: String {
    case bond
    case unbond

    var screenTitle: String {
        switch self {
        case .bond: return R.string.localizable.referralStartInviting(preferredLanguages: .currentLocale)
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
