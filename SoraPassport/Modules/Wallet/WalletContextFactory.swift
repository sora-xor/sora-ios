/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import IrohaCommunication
import SoraKeystore
import SoraCrypto
import SoraFoundation

protocol WalletContextFactoryProtocol: class {
    static func createContext() -> CommonWalletContextProtocol?
}

enum WalletContextFactoryError: Error {
    case missingEnpoint
    case requestSignerInitFailed
}

final class WalletContextFactory: WalletContextFactoryProtocol {
    static func createContext() -> CommonWalletContextProtocol? {
        let logger = Logger.shared

        do {
            let localizationManager = LocalizationManager.shared
            let locale = localizationManager.selectedLocale

            let primitiveFactory = WalletPrimitiveFactory(keychain: Keychain(),
                                                          settings: SettingsManager.shared,
                                                          localizationManager: localizationManager)

            let accountId: IRAccountId = try primitiveFactory.createAccountId()

            let accountSettings = try primitiveFactory.createAccountSettings(for: accountId)
            let networkResolver = try createNetworkResolver(with: logger)

            let inputValidFactory = WalletDescriptionInputValidatorFactory(localizationManager: localizationManager)

            let networkOperationFactory = SoraNetworkOperationFactory(accountSettings: accountSettings,
                                                                      networkResolver: networkResolver)

            let language = WalletLanguage(rawValue: localizationManager.selectedLocalization)
                ?? WalletLanguage.defaultLanguage

            let builder = CommonWalletBuilder.builder(with: accountSettings, networkResolver: networkResolver)
                .with(language: language)
                .with(logger: logger)
                .with(amountFormatter: NumberFormatter.amount.localizableResource())
                .with(transactionTypeList: primitiveFactory.createTransactionTypes())
                .with(inputValidatorFactory: inputValidFactory)
                .with(networkOperationFactory: networkOperationFactory)

            configureStyle(builder: builder.styleBuilder)

            let walletWireframe = WalletWireframe(applicationConfig: ApplicationConfig.shared)
            let headerViewModel = WalletHeaderViewModel(walletWireframe: walletWireframe)

            try configureAccountModule(with: builder.accountListModuleBuilder,
                                       headerViewModel: headerViewModel)

            configureHistoryModule(with: builder.historyModuleBuilder)
            configureContactsModule(with: builder.contactsModuleBuilder)

            configureReceiverModule(with: builder.receiveModuleBuilder,
                                    assets: accountSettings.assets,
                                    amountFormatter: NumberFormatter.amount,
                                    locale: locale)

            configureTransactionDetails(with: builder.transactionDetailsModuleBuilder,
                                        primitiveFactory: primitiveFactory)

            let walletContext = try builder.build()

            subscribeContextToLanguageSwitch(walletContext, localizationManager: localizationManager, logger: logger)

            headerViewModel.walletContext = walletContext

            return walletContext
        } catch {
            logger.error("Wallet initialization error \(error)")
            return nil
        }
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

    static private func createNetworkResolver(with logger: LoggerProtocol) throws -> WalletNetworkResolverProtocol {
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

    static private func configureAccountModule(with builder: AccountListModuleBuilderProtocol,
                                               headerViewModel: WalletHeaderViewModel) throws {
        try builder
            .with(minimumContentHeight: headerViewModel.itemHeight)
            .inserting(viewModelFactory: { headerViewModel }, at: 0)
            .with(cellNib: UINib(resource: R.nib.walletAccountHeaderView),
                  for: headerViewModel.cellReuseIdentifier)
    }

    static private func configureHistoryModule(with builder: HistoryModuleBuilderProtocol) {
        builder
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(supportsFilter: false)
            .with(includesFeeInAmount: false)
            .with(historyViewStyle: HistoryViewStyle.sora)
    }

    static private func configureContactsModule(with builder: ContactsModuleBuilderProtocol) {

        let searchPlaceholder = LocalizableResource { locale in
            R.string.localizable.contactsSearchHint(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(searchPlaceholder: searchPlaceholder)
            .with(searchEmptyStateDataSource: WalletEmptyStateDataSource.search)
            .with(contactsEmptyStateDataSource: WalletEmptyStateDataSource.contacts)
            .with(supportsLiveSearch: false)
    }

    static private func configureReceiverModule(with builder: ReceiveAmountModuleBuilderProtocol,
                                                assets: [WalletAsset],
                                                amountFormatter: NumberFormatter,
                                                locale: Locale) {

        let receiveTitle = LocalizableResource { locale in
            R.string.localizable.walletReceiveXor(preferredLanguages: locale.rLanguages)
        }

        let sharingFactory = WalletAccountSharingFactory(assets: assets,
                                                         amountFormatter: amountFormatter,
                                                         locale: locale)

        builder.with(accountShareFactory: sharingFactory).with(title: receiveTitle)
    }

    static private func configureTransactionDetails(with builder: TransactionDetailsModuleBuilderProtocol,
                                                    primitiveFactory: WalletPrimitiveFactoryProtocol) {
        builder.with(sendBackTransactionTypes: primitiveFactory.sendBackSupportIdentifiers)
    }

    static private func configureStyle(builder: WalletStyleBuilderProtocol) {
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
            .with(caretColor: UIColor.inputIndicator)
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
}
