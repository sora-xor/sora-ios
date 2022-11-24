/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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

    static func createOldView() -> OldNodesViewProtocol? {

        let view = OldNodesViewController(nib: R.nib.oldNodesViewController)
        view.localizationManager = LocalizationManager.shared

        let presenter = OldNodesPresenter()
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

    static func customOldNodeView(with chain: ChainModel, mode: NodeAction,
                                  completion: ((ChainModel) -> Void)?) -> CustomNodeViewProtocol? {
        let presenter = CustomNodePresenter(chain: chain, mode: mode, completion: completion)
        presenter.localizationManager = LocalizationManager.shared
        let isNeedRedesign = ApplicationConfig.shared.isNeedRedesign

        let view = OldCustomNodeViewController(presenter: presenter)

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
