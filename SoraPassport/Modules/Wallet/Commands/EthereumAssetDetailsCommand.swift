/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class EthereumAssetDetailsCommand {
    var undelyingCommand: WalletCommandProtocol?

    let commandFactory: WalletCommandFactoryProtocol
    let address: String
    let dataProvider: StreamableProvider<EthereumInit>
    let repository: AnyDataProviderRepository<EthereumInit>
    let operationManager: OperationManagerProtocol
    let localizationManager: LocalizationManagerProtocol

    private var registrationItem: EthereumInit?

    init(commandFactory: WalletCommandFactoryProtocol,
         dataProvider: StreamableProvider<EthereumInit>,
         repository: AnyDataProviderRepository<EthereumInit>,
         operationManager: OperationManagerProtocol,
         localizationManager: LocalizationManagerProtocol,
         address: String) {
        self.commandFactory = commandFactory
        self.dataProvider = dataProvider
        self.repository = repository
        self.operationManager = operationManager
        self.localizationManager = localizationManager
        self.address = address

        subscribeToDataProvider()
    }

    private func subscribeToDataProvider() {
        let changes: ([DataProviderChange<EthereumInit>]) -> Void = { [weak self] changes in
            for change in changes {
                switch change {
                case .insert(let newItem), .update(let newItem):
                    self?.registrationItem = newItem
                case .delete:
                    self?.registrationItem = nil
                }
            }
        }

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                        waitsInProgressSyncOnAdd: false,
                                                        refreshWhenEmpty: false)

        dataProvider.addObserver(self, deliverOn: .main,
                                 executing: changes,
                                 failing: { _ in },
                                 options: options)
    }

    private func registerAddress() {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let saveChangesClosure: () -> [EthereumInit] = {
            do {
                if
                    let item = try fetchOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        .first, item.state == .failed {
                    let changed = EthereumInit(sidechainId: item.sidechainId,
                                               state: .needsRegister,
                                               userInfo: item.userInfo)
                    return [changed]
                } else {
                    return []
                }
            } catch {
                return []
            }
        }

        let saveOperation = repository.saveOperation(saveChangesClosure, { [] })
        saveOperation.addDependency(fetchOperation)

        operationManager.enqueue(operations: [fetchOperation, saveOperation], in: .sync)
    }
}

extension EthereumAssetDetailsCommand: WalletCommandDecoratorProtocol {
    func execute() throws {
        let locale = localizationManager.selectedLocale

        let alertView = UIAlertController(title: address,
                                          message: nil,
                                          preferredStyle: .actionSheet)

        if let state = registrationItem?.state, state == .failed {
            let title = R.string.localizable
                .walletAccountRetryRegistration(preferredLanguages: locale.rLanguages)
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.registerAddress()
            }

            alertView.addAction(action)
        }

        let copyTitle = R.string.localizable.commonCopy(preferredLanguages: locale.rLanguages)
        let copyAction = UIAlertAction(title: copyTitle, style: .default) { [weak self] _ in
            UIPasteboard.general.string = self?.address
        }

        alertView.addAction(copyAction)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
        alertView.addAction(cancelAction)

        try commandFactory.preparePresentationCommand(for: alertView).execute()
    }
}
