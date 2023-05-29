import Foundation
import CommonWallet
import IrohaCrypto
import RobinHood
import FearlessUtils

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
    let accountsRepository: AnyDataProviderRepository<AccountItem>
    let assetManager: AssetManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let engine: JSONRPCEngine

    lazy var localStorageKeyFactory = LocalStorageKeyFactory()
    lazy var remoteStorageKeyFactory = StorageKeyFactory()

    init(accountSettings: WalletAccountSettingsProtocol,
         nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
         coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
         polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol,
         chainStorage: AnyDataProviderRepository<ChainStorageItem>,
         localStorageIdFactory: ChainStorageIdFactoryProtocol,
         txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
         contactsOperationFactory: WalletContactOperationFactoryProtocol,
         accountsRepository: AnyDataProviderRepository<AccountItem>,
         address: String,
         networkType: SNAddressType,
         assetManager: AssetManagerProtocol,
         totalPriceAssetId: WalletAssetId?,
         runtimeService: RuntimeCodingServiceProtocol,
         requestFactory: StorageRequestFactoryProtocol,
         engine: JSONRPCEngine) {
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
        self.runtimeService = runtimeService
        self.requestFactory = requestFactory
        self.engine = engine
    }
}
