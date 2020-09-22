/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import RobinHood
import web3swift
import BigInt
import secp256k1

typealias EthereumHashResultClosure = (Result<Data, Error>?) -> Void
typealias EthereumStateResultClosure = (Result<EthereumInitData, Error>?) -> Void

protocol EthereumRegistrationServiceProtocol {
    func sendIntention(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping EthereumHashResultClosure) -> [Operation]

    func fetchState(runCompletionIn queue: DispatchQueue,
                    completionBlock: @escaping EthereumStateResultClosure) -> [Operation]
}

enum EthereumRegistrationServiceError: Error {
    case publicKeyDeriviationFailed
    case publicKeyDecodingFailed
    case addressDeriviationFailed
    case signingFailed
    case signatureDeserializationFailed
}

final class EthereumRegistrationService: BaseService {
    let serviceUnit: ServiceUnit
    let keystore: EthereumKeystoreProtocol
    let operationFactory: EthereumRegistrationFactoryProtocol
    let requestSigner: NetworkRequestModifierProtocol?

    init(serviceUnit: ServiceUnit,
         operationFactory: EthereumRegistrationFactoryProtocol,
         keystore: EthereumKeystoreProtocol,
         requestSigner: NetworkRequestModifierProtocol?) {
        self.serviceUnit = serviceUnit
        self.operationFactory = operationFactory
        self.keystore = keystore
        self.requestSigner = requestSigner
    }
}

extension EthereumRegistrationService: EthereumRegistrationServiceProtocol {
    func sendIntention(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping EthereumHashResultClosure) -> [Operation] {
        guard let urlTemplate = serviceUnit.service(for: WalletServiceType.ethereumRegistration.rawValue) else {
            queue.async {
                completionBlock(.failure(NetworkUnitError.serviceUnavailable))
            }

            return []
        }

        let config: EthereumIntentionInfoConfig = {
            let privateKey = try self.keystore.fetchKey(for: KeystoreKey.ethKey.rawValue)
            guard let publicKey = SECP256K1.privateToPublic(privateKey: privateKey, compressed: false) else {
                throw EthereumRegistrationServiceError.publicKeyDeriviationFailed
            }

            guard let publicKeyInfo = BigInt(publicKey[1...].soraHex, radix: 16) else {
                throw EthereumRegistrationServiceError.publicKeyDecodingFailed
            }

            guard let address = Web3Utils.publicToAddress(publicKey) else {
                throw EthereumRegistrationServiceError.addressDeriviationFailed
            }

            guard let signatureData = try Web3Signer.signPersonalMessage(address.addressData,
                                                                         keystore: self.keystore,
                                                                         account: address,
                                                                         password: "") else {
                throw EthereumRegistrationServiceError.signingFailed
            }

            guard let signature = SECP256K1.unmarshalSignature(signatureData: signatureData) else {
                throw EthereumRegistrationServiceError.signatureDeserializationFailed
            }

            let signatureInfo = EthereumSignature(vPart: signature.v, rPart: signature.r, sPart: signature.s)

            return EthereumRegistrationInfo(publicKey: publicKeyInfo, signature: signatureInfo)
        }

        let operation = operationFactory.createIntentionOperation(urlTemplate.serviceEndpoint, config: config)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return [operation]
    }

    func fetchState(runCompletionIn queue: DispatchQueue,
                    completionBlock: @escaping EthereumStateResultClosure) -> [Operation] {
        guard let service = serviceUnit.service(for: WalletServiceType.ethereumState.rawValue) else {
            queue.async {
                completionBlock(.failure(NetworkUnitError.serviceUnavailable))
            }

            return []
        }

        let operation = operationFactory.createRegistrationStateOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return [operation]
    }
}
