import Foundation
import RobinHood
import IrohaCommunication
import CommonWallet

typealias EthereumIntentionInfoConfig = () throws -> EthereumRegistrationInfo

protocol EthereumRegistrationFactoryProtocol {
    func createIntentionOperation(_ urlTemplate: String,
                                  config: @escaping EthereumIntentionInfoConfig) -> NetworkOperation<Data>
    func createRegistrationStateOperation(_ urlTemplate: String) -> NetworkOperation<EthereumInitData>
}

final class EthereumRegistrationFactory: EthereumRegistrationFactoryProtocol {
    private struct Constants {
        static let storageAccountId = "eth_registration_service@notary"
        static let storageKey = "register_wallet"
        static let quorum: UInt = 2
    }

    let sender: IRAccountId
    let signer: IRSignatureCreatorProtocol
    let publicKey: IRPublicKeyProtocol

    lazy private var encoder = JSONEncoder()

    init(signer: IRSignatureCreatorProtocol, publicKey: IRPublicKeyProtocol, sender: IRAccountId) throws {
        self.signer = signer
        self.sender = sender
        self.publicKey = publicKey
    }

    func createIntentionOperation(_ urlTemplate: String,
                                  config: @escaping EthereumIntentionInfoConfig) -> NetworkOperation<Data> {
        var transactionHash: Data?

        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            let info = try config()
            let infoData = try self.encoder.encode(info)

            guard let value = String(data: infoData, encoding: .utf8)?
                .replacingOccurrencesOfIrohaSpecialCharacters() else {
                throw NetworkBaseError.badSerialization
            }

            let storage = try IRAccountIdFactory.account(withIdentifier: Constants.storageAccountId)

            let transaction = try IRTransactionBuilder(creatorAccountId: self.sender)
                .setAccountDetail(storage, key: Constants.storageKey, value: value)
                .withQuorum(Constants.quorum)
                .build()
                .signed(withSignatories: [self.signer], signatoryPublicKeys: [self.publicKey])

            transactionHash = try transaction.transactionHash()

            let transactionData = try IRSerializationFactory.serializeTransaction(transaction)
            let transactionInfo = TransactionInfo(transaction: transactionData)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try self.encoder.encode(transactionInfo)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Data> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = RegistrationDataError.error(from: resultData.status) {
                    throw resultError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let resultHash = transactionHash else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return resultHash
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createRegistrationStateOperation(_ urlTemplate: String) -> NetworkOperation<EthereumInitData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            return URLRequest(url: serviceUrl)
        }

        let resultFactory = AnyNetworkResultFactory<EthereumInitData> { data in
            let resultData = try JSONDecoder().decode(OptionalMultifieldResultData<EthereumInitData>.self,
                                                      from: data)

            guard resultData.status.isSuccess else {
                if let initDataError = EthereumInitDataError.error(from: resultData.status) {
                    throw initDataError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let result = resultData.result else {
                throw NetworkBaseError.unexpectedEmptyData
            }

            return result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
