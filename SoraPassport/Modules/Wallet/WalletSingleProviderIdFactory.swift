import Foundation
import CommonWallet
import IrohaCrypto

final class WalletSingleProviderIdFactory: SingleProviderIdentifierFactoryProtocol {
    let addressType: SNAddressType

    init(addressType: SNAddressType) {
        self.addressType = addressType
    }

    func balanceIdentifierForAccountId(_ accountId: String) -> String {
        "wallet.cache.\(accountId).\(addressType).balance"
    }

    func historyIdentifierForAccountId(_ accountId: String, assets: [String]) -> String {
        "wallet.cache.\(accountId).\(addressType).history"
    }

    func contactsIdentifierForAccountId(_ accountId: String) -> String {
        "wallet.cache.\(accountId).\(addressType).contacts"
    }

    func withdrawMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                optionId: String) -> String {
        "wallet.cache.\(accountId).\(addressType).withdraw.metadata"
    }

    func transferMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                receiverId: String) -> String {
        "wallet.cache.\(accountId).\(addressType).transfer.metadata"
    }
}
