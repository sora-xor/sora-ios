/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import RobinHood

final class NodesInteractor {
    weak var presenter: NodesInteractorOutputProtocol?

    private let settings: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    var chain: ChainModel
    private let chainRegistry = ChainRegistryFacade.sharedRegistry

    init(settings: SettingsManagerProtocol,
         chain: ChainModel,
         repository: AnyDataProviderRepository<ChainModel>,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.chain = chain
        self.chainRepository = repository
    }
}

extension NodesInteractor: NodesInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(chain: definitelySelected(self.chain))
        eventCenter.add(observer: self)
    }

    func definitelySelected(_ chain: ChainModel) -> ChainModel {
//   untill user has selected a node, connection is random one of the default
//   any user action will override this fake selection
        var newChain = chain
        if chain.selectedNode == nil,
           let node = chainRegistry.getActiveNode(for: chain.chainId) {
              newChain = chain.replacingSelectedNode(node)
        }
        return newChain
    }

    func changeSelectedNode(to newNode: ChainNodeModel) {
        let updatedChain = chain.replacingSelectedNode(newNode)

        let saveOperation = chainRepository.saveOperation {
            return [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
            self?.eventCenter.notify(with: event)
        }
        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    func removeNode(_ node: ChainNodeModel) {
        let updatedNodes = chain.customNodes?.filter { $0.identifier != node.identifier } ?? []
        var updatedChain = chain.replacingCustomNodes(updatedNodes)
        if updatedChain.selectedNode == node {
            updatedChain = updatedChain.replacingSelectedNode(nil)
        }
        
        let saveOperation = chainRepository.saveOperation {
            return [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
            self?.eventCenter.notify(with: event)
        }
        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

}

extension NodesInteractor: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        if let updated = event.updatedChains.first(where: { [weak self] updatedChain in
            guard let self = self else { return false }
            return updatedChain.chainId == self.chain.chainId
        }) {
            chain = updated
            DispatchQueue.main.async {
                self.presenter?.didReceive(chain: self.definitelySelected(self.chain))
            }
        }
    }

    func processFailedNodeConnection(event: FailedNodeConnectionEvent) {
        DispatchQueue.main.async {
            self.presenter?.showConnectionFailed()
        }
    }
}
