import Foundation
@testable import SoraPassport
import IrohaCrypto
import SoraKeystore
import RobinHood
import SSFUtils

final class AccountCreationHelper {
    static func createAccountFromMnemonic(_ mnemonicString: String? = nil,
                                          cryptoType: SoraPassport.CryptoType,
                                          name: String = "Sora Test",
                                          networkType: Chain = .sora,
                                          derivationPath: String = "",
                                          keychain: KeystoreProtocol,
                                          settings: SettingsManagerProtocol) throws {
        let mnemonic: IRMnemonicProtocol

        if let mnemonicString = mnemonicString {
            mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        } else {
            mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        }

        let request = AccountCreationRequest(username: name,
                                             type: networkType,
                                             derivationPath: derivationPath,
                                             cryptoType: cryptoType)

        let factory = AccountOperationFactory(keystore: keychain)
        let operation = factory.prepareAccountOperation(
            request: request,
            mnemonic: mnemonic
        )

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let prepared = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try factory.persistPreparedAccount(prepared)
        let accountItem = prepared.account

        try selectAccount(accountItem, settings: settings)
    }

    static func createAccountFromSeed(_ seed: String,
                                      cryptoType: SoraPassport.CryptoType,
                                      name: String = "Sora Test",
                                      networkType: Chain = .sora,
                                      derivationPath: String = "",
                                      keychain: KeystoreProtocol,
                                      settings: SettingsManagerProtocol) throws {
        let request = AccountImportSeedRequest(seed: seed,
                                               username: name,
                                               networkType: networkType,
                                               derivationPath: derivationPath,
                                               cryptoType: cryptoType)

        let factory = AccountOperationFactory(keystore: keychain)
        let operation = factory.prepareAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let prepared = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try factory.persistPreparedAccount(prepared)
        let accountItem = prepared.account

        try selectAccount(accountItem, settings: settings)
    }

    static func createAccountFromKeystore(_ filename: String,
                                          password: String,
                                          username: String,
                                          keychain: KeystoreProtocol,
                                          settings: SettingsManagerProtocol ) throws {
        guard let url = Bundle(for: AccountCreationHelper.self).url(forResource: filename, withExtension: "json") else {
            return
        }

        let data = try Data(contentsOf: url)

        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

        let info = try AccountImportJsonFactory().createInfo(from: definition)

        return try createAccountFromKeystoreData(data,
                                                 password: password,
                                                 keychain: keychain,
                                                 settings: settings,
                                                 networkType: info.networkType ?? .polkadot,
                                                 cryptoType: info.cryptoType ?? .sr25519,
                                                 username: username)
    }

    static func createAccountFromKeystoreData(_ data: Data,
                                              password: String,
                                              keychain: KeystoreProtocol,
                                              settings: SettingsManagerProtocol,
                                              networkType: Chain,
                                              cryptoType: SoraPassport.CryptoType,
                                              username: String) throws {
        guard let keystoreString = String(data: data, encoding: .utf8) else {
            return
        }

        let request = AccountImportKeystoreRequest(keystore: keystoreString,
                                                   password: password,
                                                   username: username,
                                                   networkType: networkType,
                                                   cryptoType: cryptoType)

        let factory = AccountOperationFactory(keystore: keychain)
        let operation = factory.prepareAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let prepared = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        try factory.persistPreparedAccount(prepared)
        let accountItem = prepared.account

        try selectAccount(accountItem, settings: settings)
    }

    static func selectAccount(_ accountItem: AccountItem, settings: SettingsManagerProtocol) throws {
        let type = try SS58AddressFactory().type(fromAddress: accountItem.address)

        var currentSettings = settings
        currentSettings.set(value: accountItem, for: SettingsKey.selectedAccount.rawValue)

        SelectedWalletSettings.shared.save(value: accountItem)
    }
}

extension InMemorySettingsManager: SelectedWalletSettingsProtocol {
    public var currentAccount: SoraPassport.AccountItem? {
        value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)
    }

    public var hasSelectedAccount: Bool {
        currentAccount != nil
    }

    public func performSave(value: SoraPassport.AccountItem, completionClosure: @escaping (Result<SoraPassport.AccountItem, Error>) -> Void) {
        save(value: value)
        completionClosure(.success(value))
    }

    public func performInsertAndSelect(
        prepared: PreparedAccount,
        persistSecrets: @escaping () throws -> Void,
        lifecycleLease: WalletLifecycleLease,
        completionClosure: @escaping (
            Result<SoraPassport.AccountItem, Error>
        ) -> Void
    ) {
        do {
            try persistSecrets()
            save(value: prepared.account)
            completionClosure(.success(prepared.account))
        } catch {
            completionClosure(.failure(error))
        }
    }

    public func performSelectAfterRemoval(
        value: SoraPassport.AccountItem,
        lifecycleLease: WalletLifecycleLease,
        completionClosure: @escaping (
            Result<SoraPassport.AccountItem, Error>
        ) -> Void
    ) {
        save(value: value)
        completionClosure(.success(value))
    }

    public func performUpdateName(
        account: SoraPassport.AccountItem,
        displayName: String,
        completionClosure: @escaping (
            Result<SoraPassport.AccountItem, Error>
        ) -> Void
    ) {
        let updated = account.replacingUsername(displayName)
        save(value: updated)
        completionClosure(.success(updated))
    }

    public func performUpdateAssetSettings(
        account: SoraPassport.AccountItem,
        settings: AccountSettings,
        completionClosure: @escaping (
            Result<SoraPassport.AccountItem, Error>
        ) -> Void
    ) {
        let updated = account.replacingSettings(settings)
        save(value: updated)
        completionClosure(.success(updated))
    }

    public func performSetup(completionClosure: @escaping (Result<SoraPassport.AccountItem?, Error>) -> Void) {

    }

    public func save(value: SoraPassport.AccountItem) {
        set(value: value, for: SettingsKey.selectedAccount.rawValue)
    }


}
