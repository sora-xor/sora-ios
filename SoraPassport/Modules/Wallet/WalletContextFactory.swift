import Foundation
import CoreData
import CommonWallet
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

protocol WalletContextFactoryProtocol: AnyObject {
    func createContext(connection: JSONRPCEngine, presenter: UIViewController) throws -> CommonWalletContextProtocol
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

    func createContext(connection: JSONRPCEngine, presenter: UIViewController) throws -> CommonWalletContextProtocol {

        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
            throw WalletContextFactoryError.missingAccount
        }
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)
        
        let accountSettings = try primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager)

        let amountFormatterFactory = AmountFormatterFactory()

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
                                                totalPriceAssetId: nil)

        let builder = CommonWalletBuilder.builder(with: accountSettings,
                                                  networkOperationFactory: networkFacade)

        let localizationManager = LocalizationManager.shared

        let tokenAssets = accountSettings.assets
        let decoratorFactory = WalletCommandDecoratorFactory(localizationManager: localizationManager,
                                                             assets: tokenAssets,
                                                             assetManager: assetManager,
                                                             address: selectedAccount.address)

        WalletCommonConfigurator(localizationManager: localizationManager,
                                 networkType: networkType,
                                 account: selectedAccount,
                                 decoratorFactory: decoratorFactory,
                                 assets: tokenAssets).configure(builder: builder)
        WalletCommonStyleConfigurator().configure(builder: builder.styleBuilder)

        let walletWireframe = WalletWireframe(applicationConfig: ApplicationConfig.shared)
        let headerViewModel = WalletHeaderViewModel(walletWireframe: walletWireframe,
                                                    commandDecorator: decoratorFactory)

        let accountListConfigurator = AccountListConfigurator(address: selectedAccount.address,
                                                                    chain: networkType.chain,
                                                                    commandDecorator: decoratorFactory,
                                                                    headerViewModel: headerViewModel,
                                                                    logger: logger)

        accountListConfigurator.configure(builder: builder.accountListModuleBuilder)
//will be needed soon
//        let assetDetailsConfigurator = AssetDetailsConfigurator(address: selectedAccount.address,
//                                                                chain: networkType.chain,
//                                                                purchaseProvider: purchaseProvider,
//                                                                priceAsset: priceAsset)
//        assetDetailsConfigurator.configure(builder: builder.accountDetailsModuleBuilder)

        TransactionHistoryConfigurator(amountFormatterFactory: amountFormatterFactory,
                                       assets: accountSettings.assets,
                                       assetManager: assetManager)
            .configure(builder: builder.historyModuleBuilder)

        TransactionDetailsConfigurator(account: selectedAccount,
                                       amountFormatterFactory: amountFormatterFactory,
                                       assets: accountSettings.assets,
                                       assetManager: assetManager)
            .configure(builder: builder.transactionDetailsModuleBuilder)

        let transferConfigurator = WalletTransferConfigurator(assets: accountSettings.assets, assetManager: assetManager,
                                                        amountFormatterFactory: amountFormatterFactory,
                                                        localizationManager: localizationManager)
        transferConfigurator.configure(builder: builder.transferModuleBuilder)

        let confirmConfigurator = WalletConfirmationConfigurator(assets: accountSettings.assets, assetManager: assetManager,
                                                              amountFormatterFactory: amountFormatterFactory,
                                                                 localizationManager: localizationManager)
        confirmConfigurator.configure(builder: builder.transferConfirmationBuilder, presenter: presenter)

        let contactsConfigurator = ContactsConfigurator(networkType: networkType)
        contactsConfigurator.configure(builder: builder.contactsModuleBuilder)

        let receiveConfigurator = ReceiveConfigurator(account: selectedAccount,
                                                      chain: networkType.chain,
                                                      assets: tokenAssets,
                                                      localizationManager: localizationManager)
        receiveConfigurator.configure(builder: builder.receiveModuleBuilder)

        let invoiceScanConfigurator = InvoiceScanConfigurator(networkType: networkType)
        invoiceScanConfigurator.configure(builder: builder.invoiceScanModuleBuilder)

        let context = try builder.build()

        subscribeContextToLanguageSwitch(context,
                                         localizationManager: localizationManager,
                                         logger: logger)
        headerViewModel.walletContext = context
        transferConfigurator.commandFactory = context
        confirmConfigurator.commandFactory = context
        receiveConfigurator.commandFactory = context

        return context
    }
}
