// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import SSFCloudStorage

final class AccountOptionsInteractor {
    weak var presenter: AccountOptionsInteractorOutputProtocol!

    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    private(set) var cacheFacade: CacheFacadeProtocol
    private(set) var userDataFacade: StorageFacadeProtocol
    private(set) var substrateDataFacade: StorageFacadeProtocol
    private let account: AccountItem
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private var chain: ChainModel
    private let mnemonicCreator: IRMnemonicCreatorProtocol
    private var cloudStorageService: CloudStorageServiceProtocol

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         chain: ChainModel,
         cacheFacade: CacheFacadeProtocol,
         substrateDataFacade: StorageFacadeProtocol,
         userDataFacade: StorageFacadeProtocol,
         account: AccountItem,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol,
         cloudStorageService: CloudStorageServiceProtocol) {
        self.keystore = keystore
        self.settings = settings
        self.cacheFacade = cacheFacade
        self.substrateDataFacade = substrateDataFacade
        self.userDataFacade = userDataFacade
        self.account = account
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.chain = chain
        self.mnemonicCreator = mnemonicCreator
        self.cloudStorageService = cloudStorageService
        self.eventCenter.add(observer: self)
    }
    
    private func loadPhrase() throws -> IRMnemonicProtocol? {
        guard let entropy = try keystore.fetchEntropyForAddress(account.address) else { return nil }
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy)
        return mnemonic
    }
}

extension AccountOptionsInteractor: AccountOptionsInteractorInputProtocol {

    var currentAccount: AccountItem {
        account
    }

    var accountHasEntropy: Bool {
        guard let result = try? keystore.checkEntropyForAddress(account.address) else { return false }
        return result

    }

    func getMetadata() -> AccountCreationMetadata? {
        guard let mnemonic = try? loadPhrase() else { return nil }
        
        let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                               availableNetworks: Chain.allCases,
                                               defaultNetwork: .sora,
                                               availableCryptoTypes: CryptoType.allCases,
                                               defaultCryptoType: .sr25519)
        return metadata
    }

    func updateUsername(_ username: String) {
        let account = self.account.replacingUsername(username)
        let updateOperation = accountRepository.saveOperation {
            [account]
        } _: {
            []
        }
        updateOperation.completionBlock = { [weak self] in
            self?.eventCenter.notify(with: SelectedUsernameChanged())
        }
        self.operationManager.enqueue(operations: [updateOperation], in: .transient)
    }

    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void) {
        getAccounts { [weak self] accounts in
            guard let self = self else { return }

            let customNodes = self.chain.customNodes ?? []
            completion(accounts.count == 1 && !(customNodes.isEmpty))
        }
    }
    
    func deleteBackup(completion: @escaping (Error?) -> Void) {
        let account = OpenBackupAccount(address: currentAccount.address)
        cloudStorageService.deleteBackupAccount(account: account) { [weak self] result in
            switch result {
            case .success:
                let backupedAddresses = ApplicationConfig.shared.backupedAccountAddresses
                ApplicationConfig.shared.backupedAccountAddresses = backupedAddresses.filter { $0 != self?.currentAccount.address }
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    func signInToGoogleIfNeeded(completion: ((OpenBackupAccount?) -> Void)?) {
        cloudStorageService.signInIfNeeded { [weak self] result in
            guard result == .authorized, let self = self else {
                completion?(nil)
                return
            }
            let metadata = self.getMetadata()
            let account = OpenBackupAccount(name: self.currentAccount.username,
                                            address: self.currentAccount.address,
                                            passphrase: metadata?.mnemonic.joined(separator: " ") ?? "",
                                            cryptoType: metadata?.defaultCryptoType.typeString ?? "SR25519",
                                            substrateDerivationPath: "")
            completion?(account)
        }
    }
    
    func checkCurrentAccountBackedup() async -> Bool {
        return await withCheckedContinuation { continuation in
            cloudStorageService.getBackupAccounts { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let accounts):
                    let backupedAddresses = accounts.map { $0.address }
                    
                    let searchingResult = backupedAddresses.contains(self.currentAccount.address)
                    continuation.resume(returning: searchingResult)
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func logoutAndClean() {
        let idToRemove = self.account.identifier
        let forgetOperation = accountRepository.saveOperation {
            []
        } _: {
            [idToRemove]
        }

        forgetOperation.completionBlock = { [weak self] in
            let backupedAddresses = ApplicationConfig.shared.backupedAccountAddresses
            ApplicationConfig.shared.backupedAccountAddresses = backupedAddresses.filter { $0 != self?.account.address }
            
            self?.cleanKeystore(leavingPin: true)
        }

        let countOperation =  accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        countOperation.completionBlock = { [weak self] in
            let accounts = try? countOperation.extractNoCancellableResultData()
            guard let accounts = accounts,
                        !accounts.isEmpty else {
                self?.cleanData()
                return
            }
            if let deleted = self?.account, deleted.isSelected {
                SelectedWalletSettings.shared.save(value: accounts[0])
                self?.eventCenter.notify(with: SelectedAccountChanged())
                
            }
            self?.presenter.close()
        }

        countOperation.addDependency(forgetOperation)

        operationManager.enqueue(operations: [forgetOperation, countOperation], in: .transient)
    }

}

extension AccountOptionsInteractor: EventVisitorProtocol {}

private extension AccountOptionsInteractor {

    func cleanKeystore(leavingPin: Bool = true) {
        let address = account.address
        if leavingPin {
            try? keystore.deleteEntropy(for: address)
        } else {
            try? keystore.deleteAll(for: address)
        }
    }

    func stopServices() {
        ServiceCoordinator.shared.throttle()
    }

    func cleanSettings() {
        settings.removeAll()
    }

    func cleanCoreData() {
        try? cacheFacade.databaseService.close()
        try? cacheFacade.databaseService.drop()

        try? substrateDataFacade.databaseService.close()
        try? substrateDataFacade.databaseService.drop()

        try? userDataFacade.databaseService.close()
        try? userDataFacade.databaseService.drop()
    }

    func cleanData() {
        cleanKeystore()
        cleanSettings()
        cleanCoreData()
        stopServices()
        // TODO: [SN-377] Clean Capital cache
        DispatchQueue.main.async {
            self.presenter?.restart()
        }
    }

    func getAccounts(with completion: @escaping ([AccountItem]) -> Void) {
        let persistentOperation = accountRepository.fetchAllOperation(with: .none)

        persistentOperation.completionBlock = {
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            completion(accounts)
        }

        operationManager.enqueue(operations: [persistentOperation], in: .transient)
    }
}
