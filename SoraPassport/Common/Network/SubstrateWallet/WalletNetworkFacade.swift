import Foundation
import CommonWallet
import IrohaCrypto
import RobinHood

final class WalletNetworkFacade {
    let accountSettings: WalletAccountSettingsProtocol
    let nodeOperationFactory: WalletNetworkOperationFactoryProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol
    let address: String
    let networkType: SNAddressType
    let totalPriceAssetId: WalletAssetId?
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageIdFactory: ChainStorageIdFactoryProtocol
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let contactsOperationFactory: WalletContactOperationFactoryProtocol
    let accountsRepository: AnyDataProviderRepository<ManagedAccountItem>
    let assetManager: AssetManagerProtocol

    init(accountSettings: WalletAccountSettingsProtocol,
         nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
         coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
         polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol,
         chainStorage: AnyDataProviderRepository<ChainStorageItem>,
         localStorageIdFactory: ChainStorageIdFactoryProtocol,
         txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
         contactsOperationFactory: WalletContactOperationFactoryProtocol,
         accountsRepository: AnyDataProviderRepository<ManagedAccountItem>,
         address: String,
         networkType: SNAddressType,
         assetManager: AssetManagerProtocol,
         totalPriceAssetId: WalletAssetId?) {
        self.accountSettings = accountSettings
        self.nodeOperationFactory = nodeOperationFactory
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.polkaswapNetworkOperationFactory = polkaswapNetworkOperationFactory
        self.address = address
        self.networkType = networkType
        self.totalPriceAssetId = totalPriceAssetId
        self.chainStorage = chainStorage
        self.localStorageIdFactory = localStorageIdFactory
        self.txStorage = txStorage
        self.contactsOperationFactory = contactsOperationFactory
        self.accountsRepository = accountsRepository
        self.assetManager = assetManager
    }
}
