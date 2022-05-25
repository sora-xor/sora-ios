import Foundation
import SoraKeystore
import FearlessUtils
import RobinHood

typealias RuntimeServiceProtocol = RuntimeRegistryServiceProtocol & RuntimeCodingServiceProtocol

final class SplashInteractor: SplashInteractorProtocol {
    weak var presenter: SplashPresenterProtocol!
    let settings: SettingsManagerProtocol
    let operationManager: OperationManagerProtocol
    let socketService: WebSocketServiceProtocol
    let runtimeService: RuntimeServiceProtocol

    init(settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         socketService: WebSocketServiceProtocol,
         runtimeService: RuntimeServiceProtocol) {
        self.settings = settings
        self.operationManager = operationManager
        self.socketService = socketService
        self.runtimeService = runtimeService
    }

    func setup() {
        socketService.setup()
        runtimeService.setup()
        setupChainData()
    }

    private func setupChainData() {
        let genesisOperation = createGenesisOperation(engine: socketService.connection!)
        genesisOperation.completionBlock = {
            if let genesis = try? genesisOperation.extractResultData() {
                self.settings.set(value: genesis, for: SettingsKey.externalGenesis.rawValue)
                Logger.shared.info("Runtime update gen: \(genesis)" )
            }

            self.socketService.performPrelaunchSusbscriptions()
            self.runtimeService.update(to: .sora, forced: true) //apply correct genesis
            self.continueSetup(socketService: self.socketService, runtimeService: self.runtimeService)
        }

        let operations = [genesisOperation]

        operationManager.enqueue(operations: operations, in: .blockAfter)
    }

    private func continueSetup(socketService: WebSocketServiceProtocol, runtimeService: RuntimeCodingServiceProtocol) {

        let coderOperation = runtimeService.fetchCoderFactoryOperation()
        let whiteListOperation = WhitelistOperationFactory(repository: FileRepository()).fetchWhiteListOperation(for: .sora)
        let assetsOperation = createAssetListOperation(engine: socketService.connection!)

        let setupOperation = ClosureOperation {
            let metadata = try coderOperation.extractNoCancellableResultData().metadata
            let prefixCoding = ConstantCodingPath.chainPrefix
            let depositCoding = ConstantCodingPath.existentialDeposit
            let prefixData = metadata.getConstant(in: prefixCoding.moduleName, constantName: prefixCoding.constantName)
            let existentialDepositData = metadata.getConstant(in: depositCoding.moduleName, constantName: depositCoding.constantName)

            let prefix = try? UInt8(scaleDecoder: ScaleDecoder(data: prefixData!.value))
            let deposit = try? UInt16(scaleDecoder: ScaleDecoder(data: existentialDepositData!.value))

            self.settings.set(value: prefix, for: SettingsKey.externalPrefix.rawValue)
            self.settings.set(value: deposit, for: SettingsKey.externalExistentialDeposit.rawValue)

            let assets = try? assetsOperation.extractNoCancellableResultData()
            let assetManager = AssetManager.shared
            if let whiteListData = try whiteListOperation.extractNoCancellableResultData(),
               let assets = assets {
                let whitelist = try JSONDecoder().decode([Whitelist].self, from: whiteListData)
                var filteredAssets: [AssetInfo] = []

                for var asset in assets {
                    if let listed = whitelist.first(where: { (list) -> Bool in
                        list.assetId == asset.assetId
                    }) {
                        asset.icon = listed.icon
                        filteredAssets.append(asset)
                    }
                }
                assetManager.updateWhitelisted(filteredAssets)
            } else {
                assetManager.updateAssetList(assets ?? [])
            }

            self.presenter.setupComplete()
        }

        setupOperation.addDependency(coderOperation)
        setupOperation.addDependency(assetsOperation)
        setupOperation.addDependency(whiteListOperation)
        let operations = [coderOperation, whiteListOperation, assetsOperation, setupOperation]

        OperationManagerFacade.sharedManager.enqueue(operations: operations, in: .transient)
    }

    private func createGenesisOperation(engine: JSONRPCEngine) -> BaseOperation<String> {
        var currentBlock = 0
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
    }

    private func createAssetListOperation(engine: JSONRPCEngine) -> BaseOperation<[AssetInfo]> {
        let method = RPCMethod.assetInfo

        let assetOperation = JSONRPCListOperation<[AssetInfo]>(engine: engine,
                                                               method: method)
        return assetOperation
    }
}
