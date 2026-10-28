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

import Foundation
import SoraFoundation
import SoraKeystore

import RobinHood

final class NodesViewFactory: NodesViewFactoryProtocol {
    static func createView() -> NodesViewProtocol? {
        
        let view = NodesViewController()
        view.localizationManager = LocalizationManager.shared

        let presenter = NodesPresenter()
        presenter.localizationManager = LocalizationManager.shared

        guard let chain = ChainRegistryFacade.sharedRegistry.getChain(for: Chain.sora.genesisHash()) else {
            return nil
        }
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
