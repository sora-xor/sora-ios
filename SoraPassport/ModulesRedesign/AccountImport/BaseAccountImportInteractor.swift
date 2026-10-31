// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import IrohaCrypto
import SSFUtils
import RobinHood
import SoraKeystore
import SSFCloudStorage

enum ImportAccountError: Error {
    case unexpectedError
}

class BaseAccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!
    var credentialRepairFlow: WalletMissingAccountRepairFlow?

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let supportedNetworks: [Chain]
    let defaultNetwork: Chain
    let cloudStorage: CloudStorageServiceProtocol?
    let allowedMnemonicWordCounts: Set<Int>

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         supportedNetworks: [Chain],
         defaultNetwork: Chain,
         cloudStorage: CloudStorageServiceProtocol?,
         allowedMnemonicWordCounts: Set<Int> =
             WalletMnemonicWordPolicy.retainedSoraWordCounts) {
        precondition(
            !allowedMnemonicWordCounts.isEmpty &&
                allowedMnemonicWordCounts.isSubset(
                    of: WalletMnemonicWordPolicy.retainedSoraWordCounts
                )
        )
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.keystoreImportService = keystoreImportService
        self.supportedNetworks = supportedNetworks
        self.defaultNetwork = defaultNetwork
        self.cloudStorage = cloudStorage
        self.allowedMnemonicWordCounts = allowedMnemonicWordCounts
    }


    /// Missing keys use the existing add-only import and PIN-setup transaction.
    /// Only conflicting retained material needs the extra repair/PIN screen.
    func existingAccountRequiringRepair(_ existing: AccountItem?, prepared: PreparedAccount,
                                        selection: SelectedWalletSettingsProtocol) throws -> AccountItem? {
        guard let existing else { return nil }
        guard WalletCredentialRepair.sameIdentity(existing, prepared.account) else { throw AccountCreateError.duplicated }
        if try selection.restoresKeysInPlace(existing: existing, imported: prepared.account) { return nil }
        if let flow = credentialRepairFlow, try flow.requiresExplicitRepair(prepared) { return existing }
        throw AccountCreateError.duplicated
    }

    /// Called under the normal import lease, before journals or secrets change.
    /// Consent is asynchronous, so release that lease and revalidate in the
    /// repair service after the user has supplied their PIN.
    func requestExplicitCredentialRepairIfNeeded(_ prepared: PreparedAccount,
        lifecycleLease: WalletLifecycleLease, eventCenter: EventCenterProtocol,
        completion: ((Result<AccountItem, Error>?) -> Void)?) throws -> Bool {
        guard let flow = credentialRepairFlow, try flow.requiresExplicitRepair(prepared) else { return false }
        lifecycleLease.release()
        Task { @MainActor [weak self] in
            flow.begin(prepared) { result in
                switch result {
                case .success(let account):
                    eventCenter.notify(with: SelectedAccountChanged(), completionOnMain: { [weak self] in
                        self?.presenter?.didCompleteAccountImport()
                        completion?(.success(account))
                    })
                case .failure(let error):
                    if !(error is CancellationError) { self?.presenter?.didReceiveAccountImport(error: error) }
                    completion?(.failure(error))
                }
            }
        }
        return true
    }

    private func setupKeystoreImportObserver() {
        keystoreImportService.add(observer: self)
        handleIfNeededKeystoreImport()
    }

    private func handleIfNeededKeystoreImport() {
        if let definition = keystoreImportService.definition {
            keystoreImportService.clear()
            do {
                let jsonData = try JSONEncoder().encode(definition)
                let info = try AccountImportJsonFactory().createInfo(from: definition)

                if let text = String(data: jsonData, encoding: .utf8) {
                    presenter.didSuggestKeystore(text: text, preferredInfo: info)
                }

            } catch {
                presenter.didReceiveAccountImport(error: error)
            }
        }
    }

    private func provideMetadata() {
        let metadata = AccountImportMetadata(availableSources: AccountImportSource.allCases,
                                             defaultSource: .mnemonic,
                                             availableNetworks: supportedNetworks,
                                             defaultNetwork: defaultNetwork,
                                             availableCryptoTypes: CryptoType.allCases,
                                             defaultCryptoType: .sr25519)

        presenter.didReceiveAccountImport(metadata: metadata)
    }

    func importAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem, Swift.Error>?) -> Void)?
    ) {}
    
    func validateAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?
    ) {}
    
    /// Imports a decrypted Google Drive backup. Whatever the backup holds
    /// (phrase, seed or JSON), the derived account must be the address the
    /// backup was saved for. That check runs before any Keychain write.
    /// App Store 3.8.6 backups have no key verifier, so this is what proves
    /// that the restored keys belong to the backup.
    private func importAccount(_ account: OpenBackupAccount, password: String) {
        var candidates: [BaseOperation<PreparedAccount>] = []
        let cryptoType = CryptoType(type: account.cryptoType ?? "SR25519")
        if let phrase = account.passphrase, !phrase.isEmpty,
           let mnemonic = try? mnemonicCreator.mnemonic(fromList: phrase),
           allowedMnemonicWordCounts.contains(mnemonic.allWords().count) ||
               WalletMnemonicWordPolicy.retainedShortWordCounts.contains(mnemonic.allWords().count) {
            let request = AccountCreationRequest(username: account.name ?? "", type: .sora,
                derivationPath: account.substrateDerivationPath ?? "", cryptoType: cryptoType)
            let operation = accountOperationFactory.prepareAccountOperation(request: request, mnemonic: mnemonic)
            candidates.append(WalletMnemonicWordPolicy.retainedShortWordCounts.contains(mnemonic.allWords().count)
                ? reportingShortPhrase(operation, proving: account.address) : operation)
        }
        if let seed = account.encryptedSeed?.substrateSeed, !seed.isEmpty {
            candidates.append(accountOperationFactory.prepareAccountOperation(request:
                AccountImportSeedRequest(seed: seed, username: account.name ?? "", networkType: .sora,
                    derivationPath: account.substrateDerivationPath ?? "", cryptoType: cryptoType)))
        }
        if let json = account.json?.substrateJson, !json.isEmpty {
            // The JSON's encoding has its real crypto type. Historical Drive
            // metadata sometimes incorrectly said SR25519 for other types.
            let jsonCrypto = json.data(using: .utf8).flatMap {
                try? JSONDecoder().decode(KeystoreDefinition.self, from: $0)
            }.flatMap { try? AccountImportJsonFactory().createInfo(from: $0).cryptoType } ?? cryptoType
            candidates.append(accountOperationFactory.prepareAccountOperation(request:
                AccountImportKeystoreRequest(keystore: json, password: password, username: account.name ?? "",
                    networkType: .sora, cryptoType: jsonCrypto)))
        }
        importAccountUsingOperation(Self.firstMatchingAddress(account.address, candidates: candidates), completion: nil)
    }

    /// Tells the presenter when a short historical phrase is what proves the backup's address,
    /// so the restore can warn that the wallet's keys are far easier to guess.
    private func reportingShortPhrase(_ operation: BaseOperation<PreparedAccount>,
                                      proving address: String) -> BaseOperation<PreparedAccount> {
        ClosureOperation { [weak self] in
            operation.start()
            let prepared = try operation.extractNoCancellableResultData()
            if prepared.account.address == address {
                DispatchQueue.main.async { self?.presenter?.didRestoreShortPhraseWallet() }
            }
            return prepared
        }
    }

    /// Try backup formats in order without writing. A stale phrase/seed cannot
    /// prevent a proven JSON from restoring the saved address. Gate and I/O
    /// failures still propagate rather than being reclassified as bad backups.
    static func firstMatchingAddress(
        _ expectedAddress: String, candidates: [BaseOperation<PreparedAccount>]
    ) -> BaseOperation<PreparedAccount> {
        ClosureOperation {
            var firstError: Error?
            for candidate in candidates {
                do {
                    candidate.start()
                    let prepared = try candidate.extractNoCancellableResultData()
                    guard prepared.account.address == expectedAddress else {
                        prepared.discard()
                        throw AccountCreateError.backupIdentityMismatch
                    }
                    return prepared
                } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
                    firstError = firstError ?? error
                }
            }
            throw firstError ?? ImportAccountError.unexpectedError
        }
    }

    /// A short historical phrase restores a user-supplied identity. Merely
    /// accepting the word count would silently create a different wallet after
    /// a typo or missing path. Both validation and final import use this check.
    func prepareMnemonic(_ request: AccountImportMnemonicRequest) throws -> BaseOperation<PreparedAccount> {
        let expected = request.expectedAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            throw AccountCreateError.invalidMnemonicFormat
        }
        let count = mnemonic.allWords().count
        guard allowedMnemonicWordCounts.contains(count) ||
                (WalletMnemonicWordPolicy.retainedShortWordCounts.contains(count) &&
                    expected?.isEmpty == false) else {
            throw AccountCreateError.invalidMnemonicFormat
        }
        let operation = accountOperationFactory.prepareAccountOperation(
            request: AccountCreationRequest(username: request.username, type: request.networkType,
                derivationPath: request.derivationPath, cryptoType: request.cryptoType), mnemonic: mnemonic)
        if let expected {
            return Self.requireAddress(expected, of: operation)
        }
        return operation
    }

    /// Runs the preparation, then refuses an account whose address differs
    /// from the backup's. The prepared secrets are wiped, never persisted.
    static func requireAddress(
        _ expectedAddress: String,
        of operation: BaseOperation<PreparedAccount>
    ) -> BaseOperation<PreparedAccount> {
        ClosureOperation {
            operation.start()
            let prepared = try operation.extractNoCancellableResultData()
            guard prepared.account.address == expectedAddress else {
                prepared.discard()
                throw AccountCreateError.backupIdentityMismatch
            }
            return prepared
        }
    }
}

extension BaseAccountImportInteractor: AccountImportInteractorInputProtocol {    
    func setup() {
        provideMetadata()
        setupKeystoreImportObserver()
    }

    func importAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {
        do {
            importAccountUsingOperation(try prepareMnemonic(request), completion: completion)
        } catch {
            presenter?.didReceiveAccountImport(error: error)
            completion?(.failure(error))
        }
    }

    func importAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {
        let operation =
            accountOperationFactory.prepareAccountOperation(request: request)
        importAccountUsingOperation(operation, completion: completion)
    }

    func importAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?){
        let operation =
            accountOperationFactory.prepareAccountOperation(request: request)
        importAccountUsingOperation(operation, completion: completion)
    }
    
    func validateAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        do {
            validateAccountUsingOperation(try prepareMnemonic(request), completion: completion)
        } catch {
            if let completion { completion(.failure(error)) }
            else { presenter?.didReceiveAccountImport(error: error) }
        }
    }

    func validateAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        let operation =
            accountOperationFactory.prepareAccountOperation(request: request)
        validateAccountUsingOperation(operation, completion: completion)
    }
    
    func validateAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        let operation =
            accountOperationFactory.prepareAccountOperation(request: request)
        validateAccountUsingOperation(operation, completion: completion)
    }

    func deriveMetadataFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data),
            let info = try? AccountImportJsonFactory().createInfo(from: definition) {

            presenter.didSuggestKeystore(text: keystore, preferredInfo: info)
        }
    }
    
    func importBackedupAccount(request: AccountImportBackedupRequest) {
        Task { [weak self] in
            guard let cloudStorage = self?.cloudStorage else { return }
            do {
                let account = try await cloudStorage.importBackup(account: request.account, password: request.password)
                self?.importAccount(account, password: request.password)
            } catch {
                self?.presenter.didReceiveAccountImport(error: error)
            }
        }
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
