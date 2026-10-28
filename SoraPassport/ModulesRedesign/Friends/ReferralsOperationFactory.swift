// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SoraKeystore
import SSFUtils
import RobinHood
import IrohaCrypto
import BigInt

protocol ReferralsOperationFactoryProtocol {
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<Balance>>?
    func createExtrinsicSetReferrerOperation(with address: String) -> BaseOperation<String>
    func createExtrinsicReserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String>
    func createExtrinsicUnreserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String>
    func createReferrerOperation() -> JSONRPCListOperation<String?>?
}

final class ReferralsOperationFactory {
    private let keychain: KeystoreProtocol
    private let engine: JSONRPCEngine
    private let extrinsicService: ExtrinsicServiceProtocol
    private let selectedAccount: AccountItem
    private let addressFactory = SS58AddressFactory()

    init(settings: SettingsManagerProtocol,
         keychain: KeystoreProtocol,
         engine: JSONRPCEngine,
         runtimeRegistry: RuntimeProviderProtocol,
         selectedAccount: AccountItem,
         extrinsicService: ExtrinsicServiceProtocol? = nil) {
        self.keychain = keychain
        self.engine = engine
        self.selectedAccount = selectedAccount

        self.extrinsicService = extrinsicService ?? ExtrinsicService(address: selectedAccount.address,
                                                 cryptoType: selectedAccount.cryptoType,
                                                 runtimeRegistry: runtimeRegistry
                                                 ,
                                                 engine: engine,
                                                 operationManager: OperationManagerFacade.sharedManager)
    }
}

extension ReferralsOperationFactory: ReferralsOperationFactoryProtocol {
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<Balance>>? {
        guard let accountId = try? SS58AddressFactory().accountId(fromAddress: selectedAccount.address,
                                                                  type: selectedAccount.addressType) else {
            return nil
        }

        guard let parameters = try? StorageKeyFactory().referrerBalancesKeyForId(accountId).toHex(includePrefix: true) else {
            return nil
        }

        return JSONRPCListOperation<JSONScaleDecodable<Balance>>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: [ parameters ]
        )
    }

    func createExtrinsicSetReferrerOperation(with address: String) -> BaseOperation<String> {

        let signer = SigningWrapper(keystore: keychain, account: selectedAccount)

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let call = try callFactory.setReferrer(referrer: address)
            return try builder.adding(call: call)
        }

        let operation = BaseOperation<String>()
        operation.configurationBlock = { [extrinsicService] in
            let semaphore = DispatchSemaphore(value: 0)

            extrinsicService.submit(closure, signer: signer, runningIn: .main) { [operation] result, _, _ in
                switch result {
                case let .success(hash):
                    operation.result = .success(hash)
                case let .failure(error):
                    operation.result = .failure(error)
                }
                semaphore.signal()
            }
            let status = semaphore.wait(timeout: .now() + .seconds(60))

            if status == .timedOut {
                operation.result = .failure(JSONRPCOperationError.timeout)
                return
            }
        }

        return operation
    }

    func createExtrinsicReserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String> {

        let signer = SigningWrapper(keystore: keychain, account: selectedAccount)

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let call = try callFactory.reserveReferralBalance(balance: balance)
            return try builder.adding(call: call)
        }

        let operation = BaseOperation<String>()
        operation.configurationBlock = { [extrinsicService] in
            let semaphore = DispatchSemaphore(value: 0)

            extrinsicService.submit(closure, signer: signer, runningIn: .main) { [operation] result, _, _ in
                switch result {
                case let .success(hash):
                    operation.result = .success(hash)
                case let .failure(error):
                    operation.result = .failure(error)
                }
                semaphore.signal()
            }
            let status = semaphore.wait(timeout: .now() + .seconds(60))

            if status == .timedOut {
                operation.result = .failure(JSONRPCOperationError.timeout)
                return
            }
        }

        return operation
    }

    func createExtrinsicUnreserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String> {
        
        let signer = SigningWrapper(keystore: keychain, account: selectedAccount)
        
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let call = try callFactory.unreserveReferralBalance(balance: balance)
            return try builder.adding(call: call)
        }
        
        let operation = BaseOperation<String>()
        operation.configurationBlock = { [extrinsicService] in
            let semaphore = DispatchSemaphore(value: 0)
            
            extrinsicService.submit(closure, signer: signer, runningIn: .main) { [operation] result, _, _ in
                switch result {
                case let .success(hash):
                    operation.result = .success(hash)
                case let .failure(error):
                    operation.result = .failure(error)
                }
                semaphore.signal()
            }
            let status = semaphore.wait(timeout: .now() + .seconds(60))
            
            if status == .timedOut {
                operation.result = .failure(JSONRPCOperationError.timeout)
                return
            }
        }
        
        return operation
    }

    func createReferrerOperation() -> JSONRPCListOperation<String?>? {
        guard let accountId =  try? SS58AddressFactory().accountId(
                fromAddress: selectedAccount.address,
                type: selectedAccount.addressType
            ) else { return nil }

        guard let parameters = try? StorageKeyFactory().referrersKeyForId(accountId).toHex(includePrefix: true) else {
            return nil
        }

        return JSONRPCListOperation<String?>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: [ parameters ]
        )
    }
}
