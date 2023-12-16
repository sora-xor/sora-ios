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
import SSFUtils

final class CustomNodeInteractor {
    weak var presenter: CustomNodeInteractorOutputProtocol?

    private let settings: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let chainRepository = ChainRepositoryFactory().createRepository()
    private let operationManager: OperationManagerProtocol
    private var chain: ChainModel
    private let mode: NodeAction
    private let repository: AnyDataProviderRepository<ChainModel>
    private let nodeRepository: AnyDataProviderRepository<ChainNodeModel>
    private let substrateOperationFactory: SubstrateOperationFactoryProtocol
    private var addCustomNodeOperationFactory: CustomNodeOperationFactoryProtocol?

    init(settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol,
         repository: AnyDataProviderRepository<ChainModel>,
         nodeRepository: AnyDataProviderRepository<ChainNodeModel>,
         substrateOperationFactory: SubstrateOperationFactoryProtocol,
         chain: ChainModel,
         mode: NodeAction) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.chain = chain
        self.repository = repository
        self.nodeRepository = nodeRepository
        self.substrateOperationFactory = substrateOperationFactory
        self.mode = mode
    }
}

extension CustomNodeInteractor: CustomNodeInteractorInputProtocol {

    func updateCustomNode(url: URL, name: String) {
        #if F_RELEASE
        checkGenesisBlock(url: url, name: name)
        return
        #endif
        updateConnection(url: url, name: name)
    }

    private func checkGenesisBlock(url: URL, name: String) {
        let addCustomNodeOperationFactory = CustomNodeOperationFactory(url: url)

        let operation = addCustomNodeOperationFactory.createGetGenesisBlockOperation()

        operation.completionBlock = { [weak self] in
            guard let self = self else { return }

            let genesisBlock = try? operation.extractResultData()

            guard self.settings.externalGenesis == genesisBlock else { return }

            self.updateConnection(url: url, name: name)
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    private func updateConnection(url: URL, name: String) {
        let newNode = ChainNodeModel(url: url, name: name, apikey: nil)

        var updatedNodes: [ChainNodeModel] = []
        var selectedNode = chain.selectedNode
        var needsUniqueUrl = false

        switch mode {
        case .edit(let node):
            updatedNodes = chain.customNodes?.filter { $0.identifier != node.identifier } ?? []
            if node == selectedNode {
                selectedNode = newNode
            }
        case .add:
            updatedNodes = Array(chain.customNodes ?? [])
            needsUniqueUrl = true
        default: break
        }

        updatedNodes.append(newNode)

        let updatedChain = chain.replacingCustomNodes(updatedNodes)
            .replacingSelectedNode(selectedNode)

        saveChain(updatedChain, url: url, needsUniqueUrl: needsUniqueUrl)
    }

    private func saveChain(_ updatedChain: ChainModel, url: URL, needsUniqueUrl: Bool){
        let fetchNetworkOperation = substrateOperationFactory.fetchChainOperation(url)
        let fetchNodeOperation: BaseOperation<Optional<ChainNodeModel>>

        if needsUniqueUrl  {
            fetchNodeOperation = nodeRepository.fetchOperation(
                by: url.absoluteString,
                options: RepositoryFetchOptions())
        } else {
            fetchNodeOperation =  BaseOperation.createWithResult(nil)
        }

        let saveOperation = repository.saveOperation {
            guard try fetchNodeOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled) == nil
            else {
                throw AddConnectionError.alreadyExists
            }

            guard case .success = fetchNetworkOperation.result else {
                throw AddConnectionError.invalidConnection
            }

            return [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    self.chain = updatedChain

                    let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
                    self.eventCenter.notify(with: event)

                    self.presenter?.didCompleteAdding(in: updatedChain)
                case .failure(let error):
                    self.presenter?.didReceive(error: AddConnectionError.invalidConnection)
                case .none:
                    break
                }
            }
        }

        saveOperation.addDependency(fetchNetworkOperation)

        operationManager.enqueue(operations: [fetchNodeOperation, fetchNetworkOperation, saveOperation], in: .transient)
    }
}
