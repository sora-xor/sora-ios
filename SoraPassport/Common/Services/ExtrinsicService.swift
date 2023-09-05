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
import FearlessUtils
import RobinHood
import IrohaCrypto
import BigInt

typealias FeeExtrinsicResult = Result<RuntimeDispatchInfo, Error>
typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias EstimateFeeClosure = (Result<String, Error>) -> Void
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

            let account = MultiAddress.accoundId(accountId)

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

        let infoOperation = feeDetailsOperation(queue: queue, builderOperation: builderOperation, completionClosure: completionClosure)

        let operations = [nonceOperation, headOperation, eraOperation, hashAndEraOperation,
                          codingFactoryOperation, builderOperation, infoOperation]
        operationManager.enqueue(operations: operations, in: .transient)
    }
    
    private func feeDetailsOperation(queue: DispatchQueue,
                                      builderOperation: BaseOperation<Data>,
                                      completionClosure: @escaping EstimateFeeClosure) -> JSONRPCListOperation<InclusionFeeInfo> {
        let infoOperation = JSONRPCListOperation<InclusionFeeInfo>(engine: engine,
                                                                   method: RPCMethod.feeDetails,
                                                                   timeout: 60)
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
                if case let .success(model) = infoOperation.result {
                    completionClosure(.success(model.fee))
                    return
                }
                
                if case let .failure(error) = infoOperation.result {
                    completionClosure(.failure(error))
                    return
                }

                completionClosure(.failure(BaseOperationError.parentOperationCancelled))
            }
        }

        return infoOperation
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
