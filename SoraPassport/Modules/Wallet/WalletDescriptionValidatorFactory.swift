import Foundation
import CommonWallet
import SoraFoundation

final class WalletDescriptionInputValidatorFactory: WalletInputValidatorFactoryProtocol {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func createTransferDescriptionValidator() -> WalletInputValidatorProtocol? {
        let languages = localizationManager.preferredLocalizations
        let maxLength: UInt8 = 64
        let hint = R.string.localizable
            .walletTransferNoteHint("\(maxLength)", preferredLanguages: languages)
        return WalletDefaultInputValidator(hint: hint, maxLength: maxLength)
    }

    func createWithdrawDescriptionValidator(optionId: String) -> WalletInputValidatorProtocol? {
        return WalletDefaultInputValidator.ethereumAddress
    }
}
