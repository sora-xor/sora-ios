/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCommunication
import SoraKeystore
import CommonWallet
import SoraFoundation

protocol WalletPrimitiveFactoryProtocol {
    var sendBackSupportIdentifiers: [String] { get }

    func createTransactionTypes() -> [WalletTransactionType]
    func createAssetId() throws -> IRAssetId
    func createAccountId() throws -> IRAccountId
    func createAccountSettings(for accountId: IRAccountId) throws -> WalletAccountSettingsProtocol
}

enum WalletTransactionTypeValue: String {
    case incoming = "INCOMING"
    case outgoing = "OUTGOING"
    case withdraw = "WITHDRAW"
    case reward = "REWARD"
}

enum WalletPrimitiveFactoryError: Error {
    case invalidDecentralizedId
    case invalidPrivateKey
    case keypairCreationFailed
}

final class WalletPrimitiveFactory {
    private struct Constants {
        static let transactionQuorum: UInt = 2
        static let assetName: String = "xor"
        static let domain: String = "sora"
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

        guard let privateKey = IREd25519PrivateKey(rawData: privateKeyData) else {
            throw WalletPrimitiveFactoryError.invalidPrivateKey
        }

        guard let keypair = IREd25519KeyFactory().derive(fromPrivateKey: privateKey) else {
            throw WalletPrimitiveFactoryError.keypairCreationFailed
        }

        return keypair
    }
}

extension WalletPrimitiveFactory: WalletPrimitiveFactoryProtocol {

    func createTransactionTypes() -> [WalletTransactionType] {
        let languages = localizationManager.preferredLocalizations

        let incoming = WalletTransactionType(backendName: WalletTransactionTypeValue.incoming.rawValue,
                                             displayName: "",
                                             isIncome: true,
                                             typeIcon: nil)

        let outgoing = WalletTransactionType(backendName: WalletTransactionTypeValue.outgoing.rawValue,
                                             displayName: "",
                                             isIncome: false,
                                             typeIcon: nil)

        let withdrawName = R.string.localizable.walletWithdraw(preferredLanguages: languages)
        let withdraw = WalletTransactionType(backendName: WalletTransactionTypeValue.withdraw.rawValue,
                                             displayName: withdrawName,
                                             isIncome: false,
                                             typeIcon: nil)

        let reward = WalletTransactionType(backendName: WalletTransactionTypeValue.reward.rawValue,
                                           displayName: "",
                                           isIncome: true,
                                           typeIcon: nil)

        return [incoming, outgoing, withdraw, reward]
    }

    var sendBackSupportIdentifiers: [String] {
        return [WalletTransactionTypeValue.incoming.rawValue]
    }

    func createAssetId() throws -> IRAssetId {
        let domain = try IRDomainFactory.domain(withIdentitifer: Constants.domain)
        return try IRAssetIdFactory.assetId(withName: Constants.assetName,
                                            domain: domain)
    }

    func createAccountId() throws -> IRAccountId {
        return try createAccountId(with: Constants.domain)
    }

    func createAccountSettings(for accountId: IRAccountId) throws -> WalletAccountSettingsProtocol {
        let keypair = try deriveKeypair()

        let signer = IRSigningDecorator(keystore: keychain, identifier: KeystoreKey.privateKey.rawValue)

        let assetId = try createAssetId()

        let details = LocalizableResource { R.string.localizable.assetDetails(preferredLanguages: $0.rLanguages) }

        let asset = WalletAsset(identifier: assetId,
                                symbol: String.xor,
                                details: details)

        var accountSettings = WalletAccountSettings(accountId: accountId,
                                                   assets: [asset],
                                                   signer: signer,
                                                   publicKey: keypair.publicKey())
        accountSettings.transactionQuorum = Constants.transactionQuorum

        return accountSettings
    }
}
