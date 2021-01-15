/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import CommonWallet
import SoraFoundation
import IrohaCommunication

protocol WalletPrimitiveFactoryProtocol {
    var sendBackSupportIdentifiers: [String] { get }
    var sendAgainSupportIdentifiers: [String] { get }

    func createTransactionTypes() -> [WalletTransactionType]
    func createAccountId() throws -> String
    func createXORAsset() throws -> WalletAsset
    func createVALAsset() throws -> WalletAsset 
    func createETHAsset() throws -> WalletAsset
    func createAccountSettings(for accountId: String) throws -> WalletAccountSettingsProtocol
    func createOperationSettings() throws -> MiddlewareOperationSettingsProtocol
}

enum WalletTransactionTypeValue: String {
    case incoming = "INCOMING"
    case outgoing = "OUTGOING"
    case withdraw = "WITHDRAW"
    case reward = "REWARD"
    case deposit = "DEPOSIT_ASSET"
}

enum WalletPrimitiveFactoryError: Error {
    case invalidDecentralizedId
}

final class WalletPrimitiveFactory {
    private struct Constants {
        static let transactionQuorum: UInt = 2
        static let xorAssetName: String = "xor"
        static let valAssetName: String = "val"
        static let ethAssetName: String = "eth"
        static let domain: String = "sora"
        static let xorPrecision: Int16 = 2
        static let valPrecision: Int16 = 2
        static let ethPrecision: Int16 = 18
    }

    let keychain: KeystoreProtocol
    let settings: SettingsManagerProtocol
    let localizationManager: LocalizationManagerProtocol

    init(keychain: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         localizationManager: LocalizationManagerProtocol) {
        self.keychain = keychain
        self.settings = settings
        self.localizationManager = localizationManager
    }

    private func createAccountId(with domainName: String) throws -> IRAccountId {
        guard let decentralizedId = settings.decentralizedId else {
            throw WalletPrimitiveFactoryError.invalidDecentralizedId
        }

        let accountDomain = try IRDomainFactory.domain(withIdentitifer: domainName)
        return try IRAccountIdFactory.createAccountIdFrom(decentralizedId: decentralizedId,
                                                          domain: accountDomain)
    }

    private func deriveKeypair() throws -> IRCryptoKeypairProtocol {
        let privateKeyData = try keychain.fetchKey(for: KeystoreKey.privateKey.rawValue)

        let privateKey = try IRIrohaPrivateKey(rawData: privateKeyData)

        let keypair = try IRIrohaKeyFactory().derive(fromPrivateKey: privateKey)

        return keypair
    }
}

extension WalletPrimitiveFactory: WalletPrimitiveFactoryProtocol {

    func createTransactionTypes() -> [WalletTransactionType] {

        let emptyName = LocalizableResource { _ in "" }

        let incoming = WalletTransactionType(backendName: WalletTransactionTypeValue.incoming.rawValue,
                                             displayName: emptyName,
                                             isIncome: true,
                                             typeIcon: nil)

        let outgoing = WalletTransactionType(backendName: WalletTransactionTypeValue.outgoing.rawValue,
                                             displayName: emptyName,
                                             isIncome: false,
                                             typeIcon: nil)

        let withdrawName = LocalizableResource { locale in
            R.string.localizable.walletWithdraw(preferredLanguages: locale.rLanguages)
        }

        let withdraw = WalletTransactionType(backendName: WalletTransactionTypeValue.withdraw.rawValue,
                                             displayName: withdrawName,
                                             isIncome: false,
                                             typeIcon: nil)

        let reward = WalletTransactionType(backendName: WalletTransactionTypeValue.reward.rawValue,
                                           displayName: emptyName,
                                           isIncome: true,
                                           typeIcon: nil)

        let deposit = WalletTransactionType(backendName: WalletTransactionTypeValue.deposit.rawValue,
                                            displayName: emptyName,
                                            isIncome: true,
                                            typeIcon: nil)

        return [incoming, outgoing, withdraw, reward, deposit]
    }

    var sendBackSupportIdentifiers: [String] {
        [WalletTransactionTypeValue.incoming.rawValue]
    }

    var sendAgainSupportIdentifiers: [String] {
        [WalletTransactionTypeValue.outgoing.rawValue]
    }

    func createXORAsset() throws -> WalletAsset {
        let name = LocalizableResource { R.string.localizable.assetDetails(preferredLanguages: $0.rLanguages) }
        let platform = LocalizableResource { R.string.localizable.assetXorPlatform(preferredLanguages: $0.rLanguages) }

        let domain = try IRDomainFactory.domain(withIdentitifer: Constants.domain)
        let xorAssetId = try IRAssetIdFactory.assetId(withName: Constants.xorAssetName, domain: domain).identifier()

        return WalletAsset(identifier: xorAssetId,
                           name: name,
                           platform: platform,
                           symbol: String.xor,
                           precision: Constants.xorPrecision,
                           modes: [])
    }

    func createVALAsset() throws -> WalletAsset {
        let name = LocalizableResource { R.string.localizable.assetDetailsVal(preferredLanguages: $0.rLanguages) }
        let platform = LocalizableResource { R.string.localizable.assetXorPlatform(preferredLanguages: $0.rLanguages) }

        let domain = try IRDomainFactory.domain(withIdentitifer: Constants.domain)
        let valAssetId = try IRAssetIdFactory.assetId(withName: Constants.valAssetName, domain: domain).identifier()

        return WalletAsset(identifier: valAssetId,
                           name: name,
                           platform: platform,
                           symbol: String.val,
                           precision: Constants.valPrecision)
    }

    func createETHAsset() throws -> WalletAsset {
        let name = LocalizableResource { R.string.localizable.assetEthName(preferredLanguages: $0.rLanguages) }
        let platform = LocalizableResource { R.string.localizable.assetEthPlaform(preferredLanguages: $0.rLanguages) }

        let domain = try IRDomainFactory.domain(withIdentitifer: Constants.domain)
        let xorAssetId = try IRAssetIdFactory.assetId(withName: Constants.ethAssetName, domain: domain).identifier()

        return WalletAsset(identifier: xorAssetId,
                           name: name,
                           platform: platform,
                           symbol: String.eth,
                           precision: Constants.ethPrecision,
                           modes: [.view])
    }

    func createAccountId() throws -> String {
        return try createAccountId(with: Constants.domain).identifier()
    }

    func createAccountSettings(for accountId: String) throws -> WalletAccountSettingsProtocol {
        let xor = try createXORAsset()
        let val = try createVALAsset()
        let eth = try createETHAsset()
        return WalletAccountSettings(accountId: accountId, assets: [xor, val, eth])
    }

    func createOperationSettings() throws -> MiddlewareOperationSettingsProtocol {
        let keypair = try deriveKeypair()
        let signer = IRSigningDecorator(keystore: keychain, identifier: KeystoreKey.privateKey.rawValue)

        return MiddlewareOperationSettings(signer: signer,
                                           publicKey: keypair.publicKey(),
                                           transactionQuorum: Constants.transactionQuorum)
    }
}
