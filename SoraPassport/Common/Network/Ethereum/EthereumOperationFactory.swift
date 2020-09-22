import Foundation
import web3swift
import RobinHood
import SoraKeystore
import BigInt

struct EthContractCallInfo {
    let contractAddress: Data
    let parameters: [AnyObject]
}

typealias EthContractCallConfig = () throws -> EthContractCallInfo

enum EthereumOperationFactoryError: Error {
    case publicKeyDeriviationFailed
    case addressDeriviationFailed
    case undefinedResponse
    case invalidContractParameters
    case transactionOrQueryBuildingFailed
    case transactionOrQueryEncodingFailed
    case transactionOrQueryDecodingFailed
}

enum EthereumBlock: String {
    case latest
    case earliest
    case pending
}

enum EthereumChain: UInt8 {
    case mainnet = 1
    case ropsten = 3
}

final class EthereumOperationFactory {
    let keystore: EthereumKeystoreProtocol
    let node: URL

    let addressEntity: EthereumAddress

    let chain: EthereumChain

    init(node: URL, keystore: EthereumKeystoreProtocol, chain: EthereumChain = .mainnet) throws {
        let privateKey = try keystore.fetchKey(for: KeystoreKey.ethKey.rawValue)
        guard let publicKey = Web3Utils.privateToPublic(privateKey) else {
            throw EthereumOperationFactoryError.publicKeyDeriviationFailed
        }

        guard let address = Web3Utils.publicToAddress(publicKey) else {
            throw EthereumOperationFactoryError.addressDeriviationFailed
        }

        self.keystore = keystore
        self.node = node
        self.addressEntity = address
        self.chain = chain
    }

    func createBoolResultFactory() -> AnyNetworkResultFactory<Bool> {
        AnyNetworkResultFactory { (data) in
            let response = try JSONDecoder().decode(JSONRPCresponse.self, from: data)

            if let value: BigUInt = response.getValue() {
                return value > 0 ? true : false
            }

            if let error = response.error {
                throw NSError(domain: EthereumServiceConstants.errorDomain,
                              code: error.code,
                              userInfo: [ NSLocalizedDescriptionKey: error.message ])
            }

            throw EthereumOperationFactoryError.undefinedResponse
        }
    }

    func createContractResultFactory() -> AnyNetworkResultFactory<Data> {
        AnyNetworkResultFactory { (data) in
            let response = try JSONDecoder().decode(JSONRPCresponse.self, from: data)

            if let value: Data = response.getValue(), let address = EthereumAddress(value.suffix(20)) {
                return address.addressData
            }

            if let error = response.error {
                throw NSError(domain: EthereumServiceConstants.errorDomain,
                              code: error.code,
                              userInfo: [ NSLocalizedDescriptionKey: error.message ])
            }

            throw EthereumOperationFactoryError.undefinedResponse
        }
    }

    func createResultFactory<T>() -> AnyNetworkResultFactory<T> {
        AnyNetworkResultFactory { (data) in
            let response = try JSONDecoder().decode(JSONRPCresponse.self, from: data)

            if let value: T = response.getValue() {
                return value
            }

            if let error = response.error {
                throw NSError(domain: EthereumServiceConstants.errorDomain,
                              code: error.code,
                              userInfo: [ NSLocalizedDescriptionKey: error.message ])
            }

            throw EthereumOperationFactoryError.undefinedResponse
        }
    }

    func createERC20ContractQuery(for contractAddressConfig: @escaping EthAddressConfig,
                                  method: String,
                                  parameters: [AnyObject]) -> BlockNetworkRequestFactory {
        let url = node

        return BlockNetworkRequestFactory {
            let contractAddress = try contractAddressConfig()
            guard let contract = EthereumContract(Web3.Utils.erc20ABI, at: EthereumAddress(contractAddress)) else {
                throw EthereumOperationFactoryError.invalidContractParameters
            }

            guard let transaction = contract.method(method,
                                                    parameters: parameters,
                                                    extraData: Data()) else {
                throw EthereumOperationFactoryError.transactionOrQueryBuildingFailed
            }

            guard var txParameters = transaction.encodeAsDictionary() else {
                throw EthereumOperationFactoryError.transactionOrQueryEncodingFailed
            }

            txParameters.gas = nil

            let parameters: [Encodable] = [txParameters, EthereumBlock.latest.rawValue]
            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.call,
                                                                  parameters: parameters)

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }
    }

    func createContractQuery(_ method: ABI.Element.Function,
                             callClosure: @escaping EthContractCallConfig)
        -> BlockNetworkRequestFactory {
        let url = node

        return BlockNetworkRequestFactory {
            let abi = ABI.Element.function(method)

            let callInfo = try callClosure()

            guard let address = EthereumAddress(callInfo.contractAddress) else {
                throw EthereumOperationFactoryError.transactionOrQueryBuildingFailed
            }

            guard let encodedData = abi.encodeParameters(callInfo.parameters) else {
                throw EthereumOperationFactoryError.transactionOrQueryBuildingFailed
            }

            let query = EthereumTransaction(gasPrice: BigUInt(0),
                                            gasLimit: BigUInt(0),
                                            to: address,
                                            value: BigUInt(0),
                                            data: encodedData)

            guard var txParameters = query.encodeAsDictionary() else {
                throw EthereumOperationFactoryError.transactionOrQueryEncodingFailed
            }

            txParameters.gas = nil

            let requestParameters: [Encodable] = [txParameters, EthereumBlock.latest.rawValue]
            let jsonRequest = JSONRPCRequestFabric.prepareRequest(.call,
                                                                  parameters: requestParameters)

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }
    }

    func createContractCallOperation(_ method: ABI.Element.Function,
                                     callClosure: @escaping EthContractCallConfig)
        -> BaseOperation<Data> {

        return ClosureOperation {
            let abi = ABI.Element.function(method)

            let callInfo = try callClosure()

            guard let destinationAddress = EthereumAddress(callInfo.contractAddress) else {
                throw EthereumOperationFactoryError.transactionOrQueryBuildingFailed
            }

            guard let encodedData = abi.encodeParameters(callInfo.parameters) else {
                throw EthereumOperationFactoryError.transactionOrQueryBuildingFailed
            }

            let transaction = EthereumTransaction(gasPrice: BigUInt(0),
                                                  gasLimit: BigUInt(0),
                                                  to: destinationAddress,
                                                  value: BigUInt(0),
                                                  data: encodedData)

            guard let txData = transaction.encode() else {
                throw EthereumOperationFactoryError.transactionOrQueryEncodingFailed
            }

            return txData
        }
    }
}
