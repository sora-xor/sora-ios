import Foundation
import CoreData
import CommonWallet
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

protocol WalletContextFactoryProtocol: AnyObject {
    func createContext(connection: JSONRPCEngine) throws -> CommonWalletContextProtocol
}

enum WalletContextFactoryError: Error {
    case missingEnpoint
    case requestSignerInitFailed
    case missingAccount
    case missingPriceAsset
    case missingConnection
}

final class WalletContextFactory {
    let keychain: KeystoreProtocol
    let applicationConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol
    let primitiveFactory: WalletPrimitiveFactoryProtocol

    init(keychain: KeystoreProtocol = Keychain(),
         applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
         logger: LoggerProtocol = Logger.shared) {
        self.keychain = keychain
        self.applicationConfig = applicationConfig
        self.logger = logger

        primitiveFactory = WalletPrimitiveFactory(keystore: keychain)
    }

    private func subscribeContextToLanguageSwitch(_ context: CommonWalletContextProtocol,
                                                  localizationManager: LocalizationManagerProtocol,
                                                  logger: LoggerProtocol) {
        localizationManager.addObserver(with: context) { [weak context] (_, newLocalization) in
            if let newLanguage = WalletLanguage(rawValue: newLocalization) {
                do {
                    try context?.prepareLanguageSwitchCommand(with: newLanguage).execute()
                } catch {
                    logger.error("Error received when tried to change wallet language")
                }
            } else {
                logger.error("New selected language \(newLocalization) error is unsupported")
            }
        }
    }
}

extension WalletContextFactory: WalletContextFactoryProtocol {
    //swiftlint:disable:next function_body_length

    func createContext(connection: JSONRPCEngine) throws -> CommonWalletContextProtocol {

        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
            throw WalletContextFactoryError.missingAccount
        }
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)
        
        let accountSettings = try primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager)

        logger.debug("Loading wallet account: \(selectedAccount.address)")

        let networkType = selectedAccount.addressType

        let accountSigner = SigningWrapper(keystore: Keychain(), account: selectedAccount)
        let dummySigner = try DummySigner(cryptoType: selectedAccount.cryptoType)

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let chainStorage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()

        let localStorageIdFactory = try ChainStorageIdFactory(chain: Chain.sora)
        let runtime = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())!
        let extrinsicService = ExtrinsicService(address: selectedAccount.address,
                                                cryptoType: selectedAccount.cryptoType,
                                                runtimeRegistry: runtime,
                                                engine: connection,
                                                operationManager: OperationManagerFacade.sharedManager)

        let nodeOperationFactory = WalletNetworkOperationFactory(engine: connection,
                                                                 requestFactory: StorageRequestFactory(
                                                                    remoteFactory: StorageKeyFactory(),
                                                                    operationManager: OperationManagerFacade.sharedManager
                                                                ),
                                                                 runtimeService: runtime,
                                                                 accountSettings: accountSettings,
                                                                 cryptoType: selectedAccount.cryptoType,
                                                                 accountSigner: accountSigner, extrinsicService: extrinsicService,
                                                                 dummySigner: dummySigner,
                                                                 chainStorage:
                                                                    AnyDataProviderRepository(chainStorage),
                                                                 localStorageIdFactory: localStorageIdFactory)

        let coingeckoOperationFactory = CoingeckoOperationFactory()

        let polkaswapNetworkOperationFactory = PolkaswapNetworkOperationFactory(engine: connection)

        let txFilter = NSPredicate.filterTransactionsBy(address: selectedAccount.address)
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository(filter: txFilter)

        let contactOperationFactory = WalletContactOperationFactory(storageFacade: substrateStorageFacade,
                                                                    targetAddress: selectedAccount.address)

        let accountStorage: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared
            .createRepository(filter: NSPredicate.filterAccountBy(networkType: networkType),
                              sortDescriptors: [NSSortDescriptor.accountsByOrder],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))

        let networkFacade = WalletNetworkFacade(accountSettings: accountSettings,
                                                nodeOperationFactory: nodeOperationFactory,
                                                coingeckoOperationFactory: coingeckoOperationFactory,
                                                polkaswapNetworkOperationFactory: polkaswapNetworkOperationFactory,
                                                chainStorage: AnyDataProviderRepository(chainStorage),
                                                localStorageIdFactory: localStorageIdFactory,
                                                txStorage: AnyDataProviderRepository(txStorage),
                                                contactsOperationFactory: contactOperationFactory,
                                                accountsRepository: AnyDataProviderRepository(accountStorage),
                                                address: selectedAccount.address,
                                                networkType: networkType, assetManager: assetManager,
                                                totalPriceAssetId: nil,
                                                runtimeService: runtime,
                                                requestFactory: StorageRequestFactory(
                                                    remoteFactory: StorageKeyFactory(),
                                                    operationManager: OperationManagerFacade.sharedManager
                                                ),
                                                engine: connection)
                                                

        let builder = CommonWalletBuilder.builder(with: accountSettings,
                                                  networkOperationFactory: networkFacade)

        let context = try builder.build()

        subscribeContextToLanguageSwitch(context,
                                         localizationManager: LocalizationManager.shared,
                                         logger: logger)

        return context
    }
}
