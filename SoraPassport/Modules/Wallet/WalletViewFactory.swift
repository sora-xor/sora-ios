/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import CommonWallet
import IrohaCommunication
import SoraKeystore
import SoraCrypto

protocol WalletViewFactoryProtocol: class {
    static func createView() -> UIViewController?
}

enum WalletViewFactoryError: Error {
    case invalidPrivateKey
    case keypairCreationFailed
    case missingEnpoint
    case requestSignerInitFailed
    case invalidDecentralizedId
}

enum WalletServiceType: String {
    case balance
    case history
    case search
    case transfer
    case contacts
}

final class WalletViewFactory: WalletViewFactoryProtocol {
    static func createView() -> UIViewController? {
        let logger = Logger.shared

        do {
            let accountSettings = try createAccountSettings()
            let networkResolver = try createNetworkResolver(with: logger)

            let builder = CommonWalletBuilder.builder(with: accountSettings, networkResolver: networkResolver)
                .with(logger: logger)
                .with(amountFormatter: NumberFormatter.amount)

            let headerViewModel = WalletHeaderViewModel(walletWireframe: WalletWireframe())

            configureStyle(builder: builder.styleBuilder)
            try configureAccountModule(with: builder.accountListModuleBuilder,
                                       headerViewModel: headerViewModel)
            configureHistoryModule(with: builder.historyModuleBuilder)
            configureContactsModule(with: builder.contactsModuleBuilder)

            let walletNavigationController = try builder.build()

            headerViewModel.walletController = walletNavigationController

            return walletNavigationController
        } catch {
            logger.error("Wallet initialization error \(error)")
            return nil
        }
    }

    static private func createAccountSettings() throws -> WalletAccountSettings {
        let keychain = Keychain()

        let privateKeyData = try keychain.fetchKey(for: KeystoreKey.privateKey.rawValue)

        guard let privateKey = IREd25519PrivateKey(rawData: privateKeyData) else {
            throw WalletViewFactoryError.invalidPrivateKey
        }

        guard let keypair = IREd25519KeyFactory().derive(fromPrivateKey: privateKey) else {
            throw WalletViewFactoryError.keypairCreationFailed
        }

        guard let decentralizedId = SettingsManager.shared.decentralizedId else {
            throw WalletViewFactoryError.invalidDecentralizedId
        }

        let domain = try IRDomainFactory.domain(withIdentitifer: ApplicationConfig.shared.decentralizedDomain)
        let accountId = try IRAccountIdFactory.createAccountIdFrom(decentralizedId: decentralizedId, domain: domain)
        let assetId = try IRAssetIdFactory.assetId(withName: ApplicationConfig.shared.assetName, domain: domain)

        let asset = WalletAsset(identifier: assetId,
                                symbol: String.xor,
                                details: R.string.localizable.assetDetails())
        let signer = IRSigningDecorator(keystore: keychain, identifier: KeystoreKey.privateKey.rawValue)

        return WalletAccountSettings(accountId: accountId,
                                     assets: [asset],
                                     signer: signer,
                                     publicKey: keypair.publicKey(),
                                     transactionQuorum: 2)
    }

    static private func createNetworkResolver(with logger: LoggerProtocol) throws -> WalletNetworkResolverProtocol {
        let applicationConfig = ApplicationConfig.shared
        guard let balance = applicationConfig?.defaultWalletUnit.service(for: WalletServiceType.balance.rawValue) else {
            throw WalletViewFactoryError.missingEnpoint
        }

        guard let history = applicationConfig?.defaultWalletUnit.service(for: WalletServiceType.history.rawValue) else {
            throw WalletViewFactoryError.missingEnpoint
        }

        guard let search = applicationConfig?.defaultWalletUnit.service(for: WalletServiceType.search.rawValue) else {
            throw WalletViewFactoryError.missingEnpoint
        }

        guard let contacts = applicationConfig?.defaultWalletUnit
            .service(for: WalletServiceType.contacts.rawValue) else {
            throw WalletViewFactoryError.missingEnpoint
        }

        guard
            let transfer = applicationConfig?.defaultWalletUnit
            .service(for: WalletServiceType.transfer.rawValue) else {
            throw WalletViewFactoryError.missingEnpoint
        }

        guard let requestSigner = DARequestSigner.createDefault(with: logger) else {
            throw WalletViewFactoryError.requestSignerInitFailed
        }

        let endpointMapping = WalletEndpointMapping(balance: balance.serviceEndpoint,
                                                    history: history.serviceEndpoint,
                                                    search: search.serviceEndpoint,
                                                    transfer: transfer.serviceEndpoint,
                                                    contacts: contacts.serviceEndpoint)

        return WalletNetworkResolver(enpointMapping: endpointMapping,
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
            .with(historyViewStyle: HistoryViewStyle.sora)
    }

    static private func configureContactsModule(with builder: ContactsModuleBuilderProtocol) {
        builder
            .with(searchPlaceholder: R.string.localizable.walletSearchPlaceholder())
            .with(searchEmptyStateDataSource: WalletEmptyStateDataSource.search)
            .with(contactsEmptyStateDataSource: WalletEmptyStateDataSource.contacts)
            .with(supportsLiveSearch: false)
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
