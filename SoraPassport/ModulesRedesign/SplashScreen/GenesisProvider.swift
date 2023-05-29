import FearlessUtils
import RobinHood

protocol GenesisProviderProtocol {
    func load(completion: @escaping (String?) -> Void)
}

final class GenesisProvider: GenesisProviderProtocol {
    let engine: JSONRPCEngine
    let operationQueue = OperationQueue()

    init(engine: JSONRPCEngine) {
        self.engine = engine
    }

    func load(completion: @escaping (String?) -> Void) {
        let genesisOperation = createGenesisOperation()

        genesisOperation.completionBlock = {
            let genesis = try? genesisOperation.extractResultData()
            completion(genesis)
        }

        operationQueue.addOperations([genesisOperation], waitUntilFinished: true)
    }

    private func createGenesisOperation() -> BaseOperation<String> {
#if F_RELEASE
        return JSONRPCListOperation<String>.createWithResult(Chain.sora.genesisHash())
#else
        var currentBlock = 0
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
#endif
    }
}
