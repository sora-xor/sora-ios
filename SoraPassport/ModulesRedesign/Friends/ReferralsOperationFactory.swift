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

import SoraKeystore
import FearlessUtils
import RobinHood
import IrohaCrypto
import BigInt

protocol ReferralsOperationFactoryProtocol {
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<Balance>>?
    func createExtrinsicSetReferrerOperation(with address: String) -> BaseOperation<String>
    func createExtrinsicReserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String>
    func createExtrinsicUnreserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String>
    func createReferrerOperation() -> JSONRPCListOperation<String>?
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
         selectedAccount: AccountItem) {
        self.keychain = keychain
        self.engine = engine
        self.selectedAccount = selectedAccount

        self.extrinsicService = ExtrinsicService(address: selectedAccount.address,
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
        operation.configurationBlock = { [weak self] in
            let semaphore = DispatchSemaphore(value: 0)

            self?.extrinsicService.submit(closure, signer: signer, watch: true, runningIn: .main) { [operation] result, _ in
                semaphore.signal()
                switch result {
                case let .success(hash):
                    operation.result = .success(hash)
                case let .failure(error):
                    operation.result = .failure(error)
                }
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
        operation.configurationBlock = { [weak self] in
            let semaphore = DispatchSemaphore(value: 0)

            self?.extrinsicService.submit(closure, signer: signer, watch: false, runningIn: .main) { [operation] result, _ in
                semaphore.signal()
                switch result {
                case let .success(hash):
                    operation.result = .success(hash)
                case let .failure(error):
                    operation.result = .failure(error)
                }
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
        operation.configurationBlock = { [weak self] in
            let semaphore = DispatchSemaphore(value: 0)
            
            self?.extrinsicService.submit(closure, signer: signer, watch: false, runningIn: .main) { [operation] result, _ in
                semaphore.signal()
                switch result {
                case let .success(hash):
                    operation.result = .success(hash)
                case let .failure(error):
                    operation.result = .failure(error)
                }
            }
            let status = semaphore.wait(timeout: .now() + .seconds(60))
            
            if status == .timedOut {
                operation.result = .failure(JSONRPCOperationError.timeout)
                return
            }
        }
        
        return operation
    }

    func createReferrerOperation() -> JSONRPCListOperation<String>? {
        guard let accountId =  try? SS58AddressFactory().accountId(
                fromAddress: selectedAccount.address,
                type: selectedAccount.addressType
            ) else { return nil }

        guard let parameters = try? StorageKeyFactory().referrersKeyForId(accountId).toHex(includePrefix: true) else {
            return nil
        }

        return JSONRPCListOperation<String>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: [ parameters ]
        )
    }
}
