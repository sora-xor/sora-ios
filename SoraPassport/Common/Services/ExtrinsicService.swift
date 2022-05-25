import Foundation
import FearlessUtils
import RobinHood
import IrohaCrypto
import BigInt

typealias FeeExtrinsicResult = Result<RuntimeDispatchInfo, Error>
typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias EstimateFeeClosure = (Result<RuntimeDispatchInfo, Error>) -> Void
typealias ExtrinsicSubmitClosure = (Result<String, Error>, _ extrinsicHash: String?) -> Void
typealias SubmitAndWatchExtrinsicResult = (result: Result<String, Error>, extrinsicHash: String?)
typealias SubmitExtrinsicResult = Result<String, Error>

protocol ExtrinsicServiceProtocol {
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure,
                     runningIn queue: DispatchQueue,
                     completion completionClosure: @escaping EstimateFeeClosure)

    func submit(_ closure: @escaping ExtrinsicBuilderClosure,
                signer: SigningWrapperProtocol,
                watch: Bool,
                runningIn queue: DispatchQueue,
                completion completionClosure: @escaping ExtrinsicSubmitClosure)
}

final class ExtrinsicService {
    let address: String
    let cryptoType: CryptoType
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol

    init(address: String,
         cryptoType: CryptoType,
         runtimeRegistry: RuntimeCodingServiceProtocol,
         engine: JSONRPCEngine,
         operationManager: OperationManagerProtocol) {
        self.address = address
        self.cryptoType = cryptoType
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
    }

    private func createNonceOperation() -> BaseOperation<UInt32> {
        JSONRPCListOperation<UInt32>(engine: engine,
                                     method: RPCMethod.getExtrinsicNonce,
                                     parameters: [address])
    }

    private func createBlockHeadOperation() -> BaseOperation<String> {
        JSONRPCListOperation<String>(engine: engine,
                                     method: RPCMethod.getHead,
                                     parameters: nil)
    }

    private func createEraOperation(dependingOn finalizedHead: BaseOperation<String>)
    -> JSONRPCListOperation<Block.Header> {
        let headerOperation = JSONRPCListOperation<Block.Header>(engine: self.engine,
                                                                 method: RPCMethod.getHeader)
        headerOperation.configurationBlock = {
            guard let hash = try? finalizedHead.extractNoCancellableResultData() else {
                headerOperation.cancel()
                return
            }
            headerOperation.parameters = [hash]
        }

        return headerOperation
    }

    typealias EraAndHash = (Era, String)
    private func createBlockhashAndEraOperation(dependingOn finalizedHead: BaseOperation<String>,
                                                headerOperation: JSONRPCListOperation<Block.Header>)
    -> BaseOperation<EraAndHash> {
        return ClosureOperation {
            let header = try headerOperation.extractNoCancellableResultData()
            guard let blockNumber = BigUInt(hexString: header.number, radix: 16) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let era = Era(blockNumber: UInt64(blockNumber), eraLength: 64)
            let hash = try finalizedHead.extractNoCancellableResultData()
            return(EraAndHash(era, hash))
        }
    }

    private func createCodingFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        runtimeRegistry.fetchCoderFactoryOperation()
    }

    // 
    private func createExtrinsicOperation(dependingOn nonceOperation: BaseOperation<UInt32>,
                                          hashAndEraOperation: BaseOperation<EraAndHash>,
                                          codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
                                          customClosure: @escaping ExtrinsicBuilderClosure,
                                          signingClosure: @escaping (Data) throws -> Data)
    -> BaseOperation<Data> {

        let currentCryptoType = cryptoType
        let currentAddress = address

        return ClosureOperation {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let hashAndEra = try hashAndEraOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()

            let addressType = try addressFactory.extractAddressType(from: currentAddress)
            let accountId = try addressFactory.accountId(fromAddress: currentAddress, type: addressType)

            let account = accountId

            var builder: ExtrinsicBuilderProtocol =
                try ExtrinsicBuilder(specVersion: codingFactory.specVersion,
                                     transactionVersion: codingFactory.txVersion,
                                     genesisHash: addressType.chain.genesisHash())
                    .with(address: account)
                    .with(nonce: nonce)
                    .with(era: hashAndEra.0, blockHash: hashAndEra.1)

            builder = try customClosure(builder).signing(by: signingClosure,
                                                         of: currentCryptoType.utilsType,
                                                         using: codingFactory.createEncoder(),
                                                         metadata: codingFactory.metadata)

            return try builder.build(encodingBy: codingFactory.createEncoder(),
                                     metadata: codingFactory.metadata)
        }
    }
}

extension ExtrinsicService: ExtrinsicServiceProtocol {
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure,
                     runningIn queue: DispatchQueue,
                     completion completionClosure: @escaping EstimateFeeClosure) {
        let nonceOperation = createNonceOperation()
        let headOperation = createBlockHeadOperation()
        let eraOperation = createEraOperation(dependingOn: headOperation)
        let hashAndEraOperation = createBlockhashAndEraOperation(dependingOn: headOperation, headerOperation: eraOperation)
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let currentCryptoType = cryptoType

        let signingClosure: (Data) throws -> Data = { data in
            return try DummySigner(cryptoType: currentCryptoType).sign(data).rawData()
        }

        let builderOperation = createExtrinsicOperation(dependingOn: nonceOperation,
                                                        hashAndEraOperation: hashAndEraOperation,
                                                        codingFactoryOperation: codingFactoryOperation,
                                                        customClosure: closure,
                                                        signingClosure: signingClosure)
        eraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(eraOperation)
        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(hashAndEraOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(engine: engine,
                                                                      method: RPCMethod.paymentInfo, timeout: 60)
        infoOperation.configurationBlock = {
            do {
                let extrinsic = try builderOperation.extractNoCancellableResultData().toHex(includePrefix: true)
                infoOperation.parameters = [extrinsic]
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(builderOperation)

        infoOperation.completionBlock = {
            queue.async {
                if let result = infoOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        let operations = [nonceOperation, headOperation, eraOperation, hashAndEraOperation,
                          codingFactoryOperation, builderOperation, infoOperation]
        operationManager.enqueue(operations: operations, in: .transient)
    }

    func submit(_ closure: @escaping ExtrinsicBuilderClosure,
                signer: SigningWrapperProtocol,
                watch: Bool = false,
                runningIn queue: DispatchQueue,
                completion completionClosure: @escaping ExtrinsicSubmitClosure) {
        let nonceOperation = createNonceOperation()

        let headOperation = createBlockHeadOperation()
        let eraOperation = createEraOperation(dependingOn: headOperation)
        eraOperation.addDependency(headOperation)

        let hashAndEraOperation = createBlockhashAndEraOperation(dependingOn: headOperation, headerOperation: eraOperation)
        hashAndEraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(eraOperation)

        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let signingClosure: (Data) throws -> Data = { data in
            return try signer.sign(data).rawData()
        }

        let builderOperation = createExtrinsicOperation(dependingOn: nonceOperation,
                                                        hashAndEraOperation: hashAndEraOperation,
                                                        codingFactoryOperation: codingFactoryOperation,
                                                        customClosure: closure,
                                                        signingClosure: signingClosure)

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(headOperation)
        builderOperation.addDependency(eraOperation)
        builderOperation.addDependency(hashAndEraOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let submitOperation = JSONRPCListOperation<String>(engine: engine,
                                                           method: watch ? RPCMethod.submitExtrinsicAndWatch :
                                                                            RPCMethod.submitExtrinsic,
                                                           parameters: nil,
                                                           timeout: 60)
        submitOperation.configurationBlock = {
            do {
                let extrinsic = try builderOperation
                    .extractNoCancellableResultData()
                    .toHex(includePrefix: true)

                submitOperation.parameters = [extrinsic]
            } catch {
                submitOperation.result = .failure(error)
            }
        }

        submitOperation.addDependency(builderOperation)

        submitOperation.completionBlock = {
            queue.async {
                if let result = submitOperation.result {
                    completionClosure(result, watch ? submitOperation.parameters?.first : nil)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled), nil)
                }
            }
        }

        let operations = [
            nonceOperation,
            headOperation,
            eraOperation,
            hashAndEraOperation,
            codingFactoryOperation,
            builderOperation,
            submitOperation
        ]
        operationManager.enqueue(operations: operations, in: .transient)
    }
}
