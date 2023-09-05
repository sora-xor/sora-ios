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
         operationManager: OperationManagerProtocol
    ) {
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
