import SoraUIKit

final class WarningViewModelFactory {
    func insufficientBalanceViewModel(feeAssetSymbol: String, feeAmount: Decimal, isHidden: Bool = true) -> WarningViewModel {
        let feeAmount = NumberFormatter.cryptoAssets.stringFromDecimal(feeAmount) ?? ""
        let title = R.string.localizable.commonTitleWarning(preferredLanguages: .currentLocale)
        let descriptionText = R.string.localizable.swapConfirmationScreenWarningBalanceAfterwardsTransactionIsTooSmall(feeAssetSymbol,
                                                                                                                       feeAmount,
                                                                                                                       preferredLanguages: .currentLocale)
        return WarningViewModel(
            title: title,
            descriptionText: descriptionText,
            isHidden: isHidden,
            containterBackgroundColor: .statusErrorContainer,
            contentColor: .statusError)
    }
    
    func poolShareStackedViewModel(isHidden: Bool = true) -> WarningViewModel {
        let descriptionText = R.string.localizable.polkaswapFarmingPoolInFarmingHint(preferredLanguages: .currentLocale)
        return WarningViewModel(
            descriptionText: descriptionText,
            isHidden: isHidden,
            containterBackgroundColor: .statusWarningContainer,
            contentColor: .statusWarning)
    }
}
