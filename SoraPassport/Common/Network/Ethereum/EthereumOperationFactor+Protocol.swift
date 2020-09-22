/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import web3swift
import BigInt

extension EthereumOperationFactory: EthereumOperationFactoryProtocol {

    func createEthBalanceFetchOperation(for accountAddress: Data?) -> BaseOperation<BigUInt> {
        let url = node
        let targetAddressEntity: EthereumAddress

        if let plainAddress = accountAddress, let accountAddressEntity = EthereumAddress(plainAddress) {
            targetAddressEntity = accountAddressEntity
        } else {
            targetAddressEntity = addressEntity
        }

        let parameters = [targetAddressEntity.address.lowercased(), EthereumBlock.latest.rawValue]

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.getBalance, parameters: parameters)
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory: AnyNetworkResultFactory<BigUInt> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createERC20TokenBalanceFetchOperation(from tokenAddressConfig: @escaping EthAddressConfig,
                                               for accountAddress: Data?) -> BaseOperation<BigUInt> {
        let targetAddressEntity: EthereumAddress

        if let plainAddress = accountAddress, let accountAddressEntity = EthereumAddress(plainAddress) {
            targetAddressEntity = accountAddressEntity
        } else {
            targetAddressEntity = addressEntity
        }

        let parameters = [targetAddressEntity.address.lowercased()] as [AnyObject]

        let requestFactory = createERC20ContractQuery(for: tokenAddressConfig,
                                                      method: "balanceOf",
                                                      parameters: parameters)

        let resultFactory: AnyNetworkResultFactory<BigUInt> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createXORAddressFetchOperation(from masterContractAddress: Data) -> BaseOperation<Data> {
        let output = ABI.Element.InOut(name: "", type: .address)
        let function = ABI.Element.Function(name: "tokenInstance",
                                            inputs: [],
                                            outputs: [output],
                                            constant: false,
                                            payable: false)

        let callClosure: EthContractCallConfig = {
            EthContractCallInfo(contractAddress: masterContractAddress, parameters: [])
        }

        let requestFactory = createContractQuery(function, callClosure: callClosure)

        let resultFactory: AnyNetworkResultFactory<Data> = createContractResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createGasLimitOperation(for transactionConfig: @escaping EthPreparedTransactionConfig)
        -> BaseOperation<BigUInt> {
        let url = node

        let currentAddressEntity = addressEntity

        let requestFactory = BlockNetworkRequestFactory {
            let transactionData = try transactionConfig()

            guard let transaction = EthereumTransaction.fromRaw(transactionData) else {
                throw EthereumOperationFactoryError.transactionOrQueryDecodingFailed
            }

            guard var transactionParams = transaction.encodeAsDictionary(from: currentAddressEntity) else {
                throw EthereumOperationFactoryError.transactionOrQueryEncodingFailed
            }

            transactionParams.gas = nil

            let parameters = [transactionParams] as [Encodable]

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.estimateGas, parameters: parameters)
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory: AnyNetworkResultFactory<BigUInt> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createGasPriceOperation() -> BaseOperation<BigUInt> {
        let url = node

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.gasPrice, parameters: [])
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory: AnyNetworkResultFactory<BigUInt> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createTransactionsCountOperation(for accountAddress: Data?,
                                          block: EthereumBlock) -> BaseOperation<BigUInt> {
        let url = node
        let currentAddressEntity: EthereumAddress

        if let accountAddress = accountAddress, let accountAddressEntity = EthereumAddress(accountAddress) {
            currentAddressEntity = accountAddressEntity
        } else {
            currentAddressEntity = self.addressEntity
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let parameters = [currentAddressEntity.address.lowercased(), block.rawValue]

            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.getTransactionCount, parameters: parameters)
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory: AnyNetworkResultFactory<BigUInt> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createWithdrawalCheckOperation(for hashConfig: @escaping EthWithdrawHashConfig,
                                        masterContractAddress: Data) -> BaseOperation<Bool> {
        let input = ABI.Element.InOut(name: "", type: .bytes(length: 32))
        let output = ABI.Element.InOut(name: "", type: .bool)
        let function = ABI.Element.Function(name: "used",
                                            inputs: [input],
                                            outputs: [output],
                                            constant: false,
                                            payable: false)

        let callClosure: EthContractCallConfig = {
            let hash = try hashConfig()
            return EthContractCallInfo(contractAddress: masterContractAddress,
                                       parameters: [hash as AnyObject])
        }

        let requestFactory = createContractQuery(function,
                                                 callClosure: callClosure)

        let resultFactory: AnyNetworkResultFactory<Bool> = createBoolResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createWithdrawTransactionOperation(for withdrawInfoConfig: @escaping EthWithdrawInfoConfig,
                                            tokenAddressConfig: @escaping EthAddressConfig,
                                            masterContractAddress: Data) -> BaseOperation<Data> {
        let inputs = [
                ABI.Element.InOut(name: "tokenAddress", type: .address),
                ABI.Element.InOut(name: "amount", type: .uint(bits: 256)),
                ABI.Element.InOut(name: "beneficiary", type: .address),
                ABI.Element.InOut(name: "txHash", type: .bytes(length: 32)),
                ABI.Element.InOut(name: "v", type: .array(type: .uint(bits: 8), length: 0)),
                ABI.Element.InOut(name: "r", type: .array(type: .bytes(length: 32), length: 0)),
                ABI.Element.InOut(name: "s", type: .array(type: .bytes(length: 32), length: 0)),
                ABI.Element.InOut(name: "from", type: .address)
        ]

        let function = ABI.Element.Function(name: "mintTokensByPeers",
                                            inputs: inputs,
                                            outputs: [],
                                            constant: false,
                                            payable: false)

        let callClosure: EthContractCallConfig = {
            let info = try withdrawInfoConfig()
            let tokenAddressData = try tokenAddressConfig()

            guard let tokenAddress = EthereumAddress(tokenAddressData) else {
                throw EthereumOperationFactoryError.invalidContractParameters
            }

            let proofV = info.proof.map { $0.vPart }
            let proofR = info.proof.map { $0.rPart }
            let proofS = info.proof.map { $0.sPart }

            let parameters = [
                tokenAddress.address.lowercased() as AnyObject,
                info.amount as AnyObject,
                info.destination.lowercased() as AnyObject,
                info.txHash as AnyObject,
                proofV as AnyObject,
                proofR as AnyObject,
                proofS as AnyObject,
                info.destination.lowercased() as AnyObject
            ]

            return EthContractCallInfo(contractAddress: masterContractAddress,
                                       parameters: parameters)
        }

        return createContractCallOperation(function, callClosure: callClosure)
    }

    func createERC20TransferTransactionOperation(for config: @escaping EthERC20TransferConfig)
        -> BaseOperation<Data> {
        let inputs = [
                ABI.Element.InOut(name: "to", type: .address),
                ABI.Element.InOut(name: "value", type: .uint(bits: 256))
        ]

        let function = ABI.Element.Function(name: "transfer",
                                            inputs: inputs,
                                            outputs: [],
                                            constant: false,
                                            payable: false)

        let callClosure: EthContractCallConfig = {
            let info = try config()

            guard let tokenAddress = EthereumAddress(info.tokenAddress) else {
                throw EthereumOperationFactoryError.invalidContractParameters
            }

            guard let destinationAddress = EthereumAddress(info.destinationAddress) else {
                throw EthereumOperationFactoryError.invalidContractParameters
            }

            let parameters = [
                destinationAddress.address.lowercased() as AnyObject,
                info.amount as AnyObject
            ]

            return EthContractCallInfo(contractAddress: tokenAddress.addressData, parameters: parameters)
        }

        return createContractCallOperation(function, callClosure: callClosure)
    }

    func createSendTransactionOperation(for transactionInfoConfig: @escaping EthReadyTransactionConfig)
        -> BaseOperation<Data> {
        let url = node

        let currentKeystore = keystore
        let currentAddressEntity = addressEntity
        let currentChain = chain

        let requestFactory = BlockNetworkRequestFactory {
            let transactionInfo = try transactionInfoConfig()

            guard var transaction = EthereumTransaction.fromRaw(transactionInfo.txData) else {
                throw EthereumOperationFactoryError.transactionOrQueryDecodingFailed
            }

            transaction.UNSAFE_setChainID(BigUInt(currentChain.rawValue))
            transaction.gasLimit = transactionInfo.gasLimit
            transaction.gasPrice = transactionInfo.gasPrice
            transaction.nonce = transactionInfo.nonce

            try Web3Signer.signTX(transaction: &transaction,
                                  keystore: currentKeystore,
                                  account: currentAddressEntity, password: "")

            guard let transactionData = transaction.encode() else {
                throw EthereumOperationFactoryError.transactionOrQueryEncodingFailed
            }

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.sendRawTransaction,
                                                                  parameters: [transactionData.soraHexWithPrefix])
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory: AnyNetworkResultFactory<Data> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createTransactionByHashFetchOperation(_ transactionHash: Data)
        -> BaseOperation<TransactionDetails?> {
        let url = node

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let parameters = [transactionHash.soraHexWithPrefix.lowercased()]

            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.getTransactionByHash,
                                                                  parameters: parameters)
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory: AnyNetworkResultFactory<TransactionDetails?> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory,
                                resultFactory: resultFactory)
    }
}
