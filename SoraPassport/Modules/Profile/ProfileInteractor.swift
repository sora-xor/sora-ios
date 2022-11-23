/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import SoraKeystore

final class ProfileInteractor {
	weak var presenter: ProfileInteractorOutputProtocol?

    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    private(set) var cacheFacade: CacheFacadeProtocol
    private(set) var userDataFacade: StorageFacadeProtocol
    private(set) var substrateDataFacade: StorageFacadeProtocol
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private var chain: ChainModel
    private let chainRepository = ChainRepositoryFactory().createRepository()
    private let chainRegistry = ChainRegistryFacade.sharedRegistry

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         chain: ChainModel,
         cacheFacade: CacheFacadeProtocol,
         substrateDataFacade: StorageFacadeProtocol,
         userDataFacade: StorageFacadeProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol) {

        self.keystore = keystore
        self.settings = settings
        self.cacheFacade = cacheFacade
        self.substrateDataFacade = substrateDataFacade
        self.userDataFacade = userDataFacade
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.chain = chain
        self.eventCenter.add(observer: self)
    }

    var currentAccount: AccountItem? {
        SelectedWalletSettings.shared.currentAccount
    }
}

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func getCurrentNodeName(completion: @escaping (String) -> Void) {
        let node = chainRegistry.getActiveNode(for: chain.chainId)
        completion(node?.name ?? "")
    }

    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void) {
        getAccounts { [weak self] accounts in
            guard let self = self else { return }

            let customNodes = self.chain.customNodes ?? []
            completion(accounts.count == 1 && !(customNodes.isEmpty))
        }
    }
    
    var isThereEntropy: Bool {
        guard let address = currentAccount?.address, let result = try? keystore.checkEntropyForAddress(address) else { return false }
        return result 
    }

    func logoutAndClean() {
        getAccounts { [weak self] accounts in
            guard accounts.count > 1 else {
                self?.cleanData()
                return
            }
            self?.cleanKeystore()
            self?.update(accounts)
        }
    }
}

private extension ProfileInteractor {

    func cleanKeystore() {
        let address = currentAccount?.address ?? ""
        try? keystore.deleteAll(for: address)
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
    
    private func update(_ accounts: [AccountItem]) {

        let accounts = accounts.filter { !$0.isSelected }

        let replaceOperation = self.accountRepository.replaceOperation { accounts }

        replaceOperation.completionBlock = {

            self.eventCenter.notify(with: SelectedAccountChanged())

            DispatchQueue.main.async {
                self.presenter?.updateScreen()
            }

        }

        self.operationManager.enqueue(operations: [replaceOperation], in: .transient)
    }
}

extension ProfileInteractor: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        if let updated = event.updatedChains.first(where: { [weak self] updatedChain in
            guard let self = self else { return false }
            return updatedChain.chainId == self.chain.chainId
        }) {
            chain = updated

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.presenter?.updateScreen()
            }
        }
    }
}
