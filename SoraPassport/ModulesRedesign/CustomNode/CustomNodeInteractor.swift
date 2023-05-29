import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils

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
