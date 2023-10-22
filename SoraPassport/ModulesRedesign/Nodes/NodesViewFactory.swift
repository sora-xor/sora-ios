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
import SoraFoundation
import SoraKeystore
import CommonWallet
import RobinHood

final class NodesViewFactory: NodesViewFactoryProtocol {
    static func createView() -> NodesViewProtocol? {
        
        let view = NodesViewController()
        view.localizationManager = LocalizationManager.shared

        let presenter = NodesPresenter()
        presenter.localizationManager = LocalizationManager.shared

        let chain = ChainRegistryFacade.sharedRegistry.getChain(for: Chain.sora.genesisHash())!
        let repository = ChainRepositoryFactory().createRepository()
        let interactor = NodesInteractor(settings: SettingsManager.shared,
                                         chain: chain,
                                         repository: AnyDataProviderRepository(repository),
                                         eventCenter: EventCenter.shared,
                                         operationManager:  OperationManager(operationQueue: OperationManagerFacade.runtimeBuildingQueue))

        let wireframe = NodesWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    static func customNodeView(with chain: ChainModel, mode: NodeAction,
                                  completion: ((ChainModel) -> Void)?) -> CustomNodeViewProtocol? {
        let presenter = CustomNodePresenter(chain: chain, mode: mode, completion: completion)
        presenter.localizationManager = LocalizationManager.shared

        let view = CustomNodeViewController(presenter: presenter)

        view.localizationManager = LocalizationManager.shared

        let facade = SubstrateDataStorageFacade.shared

        let repository: CoreDataRepository<ChainModel, CDChain> = ChainRepositoryFactory().createRepository()

        let mapper = ChainNodeModelMapper()

        let nodeRepository: CoreDataRepository<ChainNodeModel, CDChainNode> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)

        let interactor = CustomNodeInteractor(settings: SettingsManager.shared,
                                                 eventCenter: EventCenter.shared,
                                                 operationManager: OperationManager(operationQueue: OperationManagerFacade.runtimeBuildingQueue),
                                                 repository: AnyDataProviderRepository(repository),
                                                 nodeRepository: AnyDataProviderRepository(nodeRepository),
                                                 substrateOperationFactory: substrateOperationFactory,
                                                 chain: chain,
                                              mode: mode)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        return view
    }
}
