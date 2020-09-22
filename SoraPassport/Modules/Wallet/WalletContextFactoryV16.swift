import Foundation
import CoreData
import CommonWallet
import SoraKeystore
import SoraCrypto
import SoraFoundation
import RobinHood

final class WalletContextFactoryV16: WalletContextFactoryProtocol {
    //swiftlint:disable:next function_body_length
    static func createContext() -> CommonWalletContextProtocol? {
        let logger = Logger.shared

        do {
            let localizationManager = LocalizationManager.shared
            let userStoreFacade = UserStoreFacade.shared

            let primitiveFactory = WalletPrimitiveFactoryV16(keychain: Keychain(),
                                                             settings: SettingsManager.shared,
                                                             localizationManager: localizationManager)

            let accountId = try primitiveFactory.createAccountId()

            let accountSettings = try primitiveFactory.createAccountSettings(for: accountId)

            let xorAsset = try primitiveFactory.createXORAsset()
            let ethAsset = try primitiveFactory.createETHAsset()

            let amountFormatterFactory = WalletAmountFormatterFactory(ethAssetId: ethAsset.identifier)

            let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared
            let ethereumOperationFactory =
                try EthereumOperationFactory(node: applicationConfig.ethereumNodeUrl,
                                             keystore: Keychain(),
                                             chain: applicationConfig.ethereumChainId)

            let ethereumAddress = ethereumOperationFactory.addressEntity.address

            let sharedOperationManager = OperationManagerFacade.sharedManager
            let ethInitId = SidechainId.eth.rawValue
            let ethInitRepository: AnyDataProviderRepository<EthereumInit> =
                    try createRepository(ethInitId, facade: userStoreFacade)
            let ethInitProvider: StreamableProvider<EthereumInit> =
                try createAssetDataProviderForId(ethInitId,
                                                 repository: ethInitRepository,
                                                 facade: userStoreFacade,
                                                 operationManager: sharedOperationManager,
                                                 logger: logger)

            let commandDecorator = WalletCommandDecoratorFactory(xorAssetId: xorAsset.identifier,
                                                                 ethereumAssetId: ethAsset.identifier,
                                                                 ethereumAddress: ethereumAddress,
                                                                 xorAddress: accountId,
                                                                 dataProvider: ethInitProvider,
                                                                 repository: ethInitRepository,
                                                                 localizationManager: localizationManager,
                                                                 operationManager: sharedOperationManager,
                                                                 amountFormatter: amountFormatterFactory.createTokenFormatter(for: xorAsset),
                                                                 logger: logger)

            let builder = try configureBuilder(for: accountSettings,
                                               primitiveFactory: primitiveFactory,
                                               localizationManager: localizationManager,
                                               amountFormatterFactory: amountFormatterFactory,
                                               ethereumOperationFactory: ethereumOperationFactory)

            builder.with(commandDecoratorFactory: commandDecorator)

            configureStyle(builder: builder.styleBuilder)

            let walletWireframe = WalletWireframe(applicationConfig: ApplicationConfig.shared)
            let headerViewModel = WalletHeaderViewModel(walletWireframe: walletWireframe)

            let accountConfigurator = AccountListConfigurator(dataProvider: ethInitProvider,
                                                              commandDecorator: commandDecorator,
                                                              amountFormatterFactory: amountFormatterFactory,
                                                              xorAsset: xorAsset,
                                                              ethAsset: ethAsset,
                                                              headerViewModel: headerViewModel,
                                                              logger: logger)
            accountConfigurator.configure(using: builder.accountListModuleBuilder)

            let historyConfigurator =
                TransactionHistoryConfigurator(amountFormatterFactory: amountFormatterFactory,
                                               assets: accountSettings.assets,
                                               accountId: accountId,
                                               ethereumAddress: ethereumAddress)
            historyConfigurator.configure(using: builder.historyModuleBuilder)

            configureContactsModule(with: builder.contactsModuleBuilder)

            configureReceiverModule(with: builder.receiveModuleBuilder,
                                    assets: accountSettings.assets,
                                    localizationManager: localizationManager,
                                    amountFormatterFactory: amountFormatterFactory)

            let soranetExplorerTemplate = applicationConfig.soranetExplorerTemplate
            let ethereumExplorerTemplate = applicationConfig.ethereumExplorerTemplate
            let transactionDetails =
                WalletTransactionDetailsConfigurator(feeDisplayFactory: WalletFeeDisplaySettingsFactory(),
                                                     amountFormatterFactory: amountFormatterFactory,
                                                     assets: accountSettings.assets,
                                                     accountId: accountId,
                                                     ethereumAddress: ethereumAddress,
                                                     soranetExplorerTemplate: soranetExplorerTemplate,
                                                     ethereumExplorerTemplate: ethereumExplorerTemplate)

            transactionDetails.configure(using: builder.transactionDetailsModuleBuilder)

            // TODO: use WalletTransferConfigurator to enable ethereum features
            WalletTransferConfiguratorV16(localizationManager: localizationManager,
                                          amountFormatterFactory: amountFormatterFactory,
                                          xorAsset: xorAsset,
                                          ethAsset: ethAsset)
                .configure(using: builder.transferModuleBuilder)

            WalletConfirmationConfigurator(amountFormatterFactory: amountFormatterFactory,
                                           feeDisplayFactory: WalletFeeDisplaySettingsFactory(),
                                           xorAsset: xorAsset,
                                           ethAsset: ethAsset)
                .configure(using: builder.transferConfirmationBuilder)

            let walletContext = try builder.build()

            subscribeContextToLanguageSwitch(walletContext, localizationManager: localizationManager, logger: logger)

            headerViewModel.walletContext = walletContext
            accountConfigurator.commandFactory = walletContext
            historyConfigurator.commandFactory = walletContext
            transactionDetails.commandFactory = walletContext

            return walletContext
        } catch {
            logger.error("Wallet initialization error \(error)")
            return nil
        }
    }

    static private func configureBuilder(for account: WalletAccountSettingsProtocol,
                                         primitiveFactory: WalletPrimitiveFactoryProtocol,
                                         localizationManager: LocalizationManagerProtocol,
                                         amountFormatterFactory: NumberFormatterFactoryProtocol,
                                         ethereumOperationFactory: EthereumOperationFactory)
        throws -> CommonWalletBuilderProtocol {

        let networkResolver = try createNetworkResolver(with: Logger.shared)

        let inputValidFactory = WalletDescriptionInputValidatorFactory(localizationManager: localizationManager)

        let operationSettings = try primitiveFactory.createOperationSettings()

        let soranetOperationFactory = SoraNetworkOperationFactory(accountSettings: account,
                                                                  operationSettings: operationSettings,
                                                                  networkResolver: networkResolver)

        let networkFacade = WalletNetworkFacadeV16(soranetOperationFactory: soranetOperationFactory)

        let language = WalletLanguage(rawValue: localizationManager.selectedLocalization)
            ?? WalletLanguage.defaultLanguage

        return CommonWalletBuilder.builder(with: account, networkOperationFactory: networkFacade)
            .with(language: language)
            .with(logger: Logger.shared)
            .with(amountFormatterFactory: amountFormatterFactory)
            .with(transactionTypeList: primitiveFactory.createTransactionTypes())
            .with(inputValidatorFactory: inputValidFactory)
            .with(feeDisplaySettingsFactory: WalletFeeDisplaySettingsFactory())
            .with(singleProviderIdentifierFactory: WalletSingleProviderIdFactory())
    }

    static private func subscribeContextToLanguageSwitch(_ context: CommonWalletContextProtocol,
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

    static func createNetworkResolver(with logger: LoggerProtocol) throws -> MiddlewareNetworkResolverProtocol {
        let walletUnit = ApplicationConfig.shared.defaultWalletUnit
        guard let balance = walletUnit.service(for: WalletServiceType.balance.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let history = walletUnit.service(for: WalletServiceType.history.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let search = walletUnit.service(for: WalletServiceType.search.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let contacts = walletUnit.service(for: WalletServiceType.contacts.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let transfer = walletUnit.service(for: WalletServiceType.transfer.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let transferMetadata = walletUnit.service(for: WalletServiceType.transferMetadata.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let withdraw = walletUnit.service(for: WalletServiceType.withdraw.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let withdrawalMetadata = walletUnit.service(for: WalletServiceType.withdrawalMetadata.rawValue) else {
            throw WalletContextFactoryError.missingEnpoint
        }

        guard let requestSigner = DARequestSigner.createDefault(with: logger) else {
            throw WalletContextFactoryError.requestSignerInitFailed
        }

        let endpointMapping = WalletEndpointMapping(balance: balance.serviceEndpoint,
                                                    history: history.serviceEndpoint,
                                                    search: search.serviceEndpoint,
                                                    transfer: transfer.serviceEndpoint,
                                                    transferMetadata: transferMetadata.serviceEndpoint,
                                                    contacts: contacts.serviceEndpoint,
                                                    withdraw: withdraw.serviceEndpoint,
                                                    withdrawalMetadata: withdrawalMetadata.serviceEndpoint)

        return WalletNetworkResolver(endpointMapping: endpointMapping,
                                     requestSigner: requestSigner)
    }

    static private func configureContactsModule(with builder: ContactsModuleBuilderProtocol) {

        let searchPlaceholder = LocalizableResource { locale in
            R.string.localizable.contactsSearchHintV1(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(searchPlaceholder: searchPlaceholder)
            .with(searchEmptyStateDataSource: WalletEmptyStateDataSource.search)
            .with(contactsEmptyStateDataSource: WalletEmptyStateDataSource.contacts)
            .with(scanPosition: .barButton)
            .with(withdrawOptionsPosition: .notInclude)
            .with(supportsLiveSearch: false)
            .with(canFindItself: true)
    }

    static private func configureReceiverModule(with builder: ReceiveAmountModuleBuilderProtocol,
                                                assets: [WalletAsset],
                                                localizationManager: LocalizationManagerProtocol,
                                                amountFormatterFactory: NumberFormatterFactoryProtocol) {

        let receiveTitle = LocalizableResource { locale in
            R.string.localizable.walletReceiveXor(preferredLanguages: locale.rLanguages)
        }

        let sharingFactory = WalletAccountSharingFactory(assets: assets,
                                                         numberFactory: amountFormatterFactory,
                                                         localizationManager: localizationManager)

        builder.with(accountShareFactory: sharingFactory).with(title: receiveTitle)
    }

    static private func configureStyle(builder: WalletStyleBuilderProtocol) {
        let errorStyle = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                                titleFont: R.font.soraRc0040417Regular(size: 12)!,
                                                icon: R.image.iconWarning()!)
        builder
            .with(background: .background)
            .with(navigationBarStyle: createNavigationBarStyle())
            .with(header1: R.font.soraRc0040417Bold(size: 30.0)!)
            .with(header2: R.font.soraRc0040417SemiBold(size: 18.0)!)
            .with(header3: R.font.soraRc0040417Bold(size: 16.0)!)
            .with(header4: R.font.soraRc0040417Bold(size: 15.0)!)
            .with(bodyBold: R.font.soraRc0040417Bold(size: 14.0)!)
            .with(bodyRegular: R.font.soraRc0040417Regular(size: 14.0)!)
            .with(small: R.font.soraRc0040417Regular(size: 14.0)!)
            .with(keyboardIcon: R.image.iconKeyboardOff()!)
            .with(caretColor: UIColor.inputIndicator)
            .with(inlineErrorStyle: errorStyle)
    }

    static private func createNavigationBarStyle() -> WalletNavigationBarStyleProtocol {
        var navigationBarStyle = WalletNavigationBarStyle(barColor: UIColor.navigationBarColor,
                                                          shadowColor: UIColor.darkNavigationShadowColor,
                                                          itemTintColor: UIColor.navigationBarBackTintColor,
                                                          titleColor: UIColor.navigationBarTitleColor,
                                                          titleFont: UIFont.navigationTitleFont)
        navigationBarStyle.titleFont = .navigationTitleFont
        navigationBarStyle.titleColor = .navigationBarTitleColor
        return navigationBarStyle
    }

    static private func createRepository<T: Codable>(_ identifier: String,
                                                     facade: UserStoreFacadeProtocol) throws
        -> AnyDataProviderRepository<SidechainInit<T>> {
        let mapper = SidechainInitDataMapper<T>()

        let filter = NSPredicate(format: "%K == %@",
                                 #keyPath(CDSidechainInit.identifier),
                                 identifier)

        let repository = facade.createCoreDataCache(filter: filter,
                                                    mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    static private func createAssetDataProviderForId<T: Codable>(_ identifier: String,
                                                                 repository: AnyDataProviderRepository<SidechainInit<T>>,
                                                                 facade: UserStoreFacadeProtocol,
                                                                 operationManager: OperationManagerProtocol,
                                                                 logger: LoggerProtocol) throws
        -> StreamableProvider<SidechainInit<T>> {

        let source = EmptyStreamableDataSource<SidechainInit<T>>()

        let predicate: (NSManagedObject) -> Bool = { item in
            if let sideChainInit = item as? CDSidechainInit, sideChainInit.identifier == identifier {
                return true
            } else {
                return false
            }
        }

        let mapper = SidechainInitDataMapper<T>()

        let observable: CoreDataContextObservable<SidechainInit<T>, CDSidechainInit> =
            CoreDataContextObservable(service: facade.databaseService,
                                      mapper: AnyCoreDataMapper(mapper),
                                      predicate: predicate)

        observable.start { error in
            if let error = error {
                logger.error("Can't start observable: \(error)")
            }
        }

        return StreamableProvider(source: AnyStreamableSource(source),
                                  repository: repository,
                                  observable: AnyDataProviderRepositoryObservable(observable),
                                  operationManager: operationManager)
    }
}
