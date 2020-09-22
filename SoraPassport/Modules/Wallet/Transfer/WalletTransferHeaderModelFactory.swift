import Foundation
import CommonWallet
import SoraFoundation

struct WalletTransferHeaderModelFactory: OperationDefinitionHeaderModelFactoryProtocol {

    func createAssetTitle(assetId: String,
                          receiverId: String?,
                          locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        let text = R.string.localizable.transactionToken(preferredLanguages: locale.rLanguages)

        return MultilineTitleIconViewModel(text: text)
    }

    func createAmountTitle(assetId: String,
                           receiverId: String?,
                           locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        let text = R.string.localizable.transactionAmountTitle(preferredLanguages: locale.rLanguages)
        return MultilineTitleIconViewModel(text: text)
    }

    func createReceiverTitle(assetId: String,
                             receiverId: String?,
                             locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        let text: String

        if let receiverId = receiverId, NSPredicate.ethereumAddress.evaluate(with: receiverId) {
            text = R.string.localizable.walletTransferToEthereum(preferredLanguages: locale.rLanguages)
        } else {
            text = R.string.localizable.transactionReceiverTitle(preferredLanguages: locale.rLanguages)
        }

        return MultilineTitleIconViewModel(text: text)
    }

    func createFeeTitleForDescription(assetId: String,
                                      receiverId: String?,
                                      feeDescription: Fee,
                                      locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        if feeDescription.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier {
            let text = R.string.localizable.transactionMinerHelp(preferredLanguages: locale.rLanguages)
            return MultilineTitleIconViewModel(text: text,
                                               icon: R.image.iconWalletInfo())
        } else {
            return nil
        }
    }

    func createDescriptionTitle(assetId: String,
                                receiverId: String?,
                                locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        let text = R.string.localizable.transactionNote(preferredLanguages: locale.rLanguages)
        return MultilineTitleIconViewModel(text: text, icon: R.image.iconNote())
    }
}
