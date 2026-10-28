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

import BigInt

import SSFUtils
import Foundation
import IrohaCrypto
import RobinHood
import SSFModels
import SSFStorageQueryKitFixed

final class WalletNetworkOperationFactory {
    let accountSettings: WalletAccountSettingsProtocol
    let engine: JSONRPCEngine
    let requestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let accountSigner: SigningWrapperProtocol
    let dummySigner: IRSignatureCreatorProtocol
    let cryptoType: CryptoType
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageIdFactory: ChainStorageIdFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol

    init(engine: JSONRPCEngine,
         requestFactory: StorageRequestFactoryProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         accountSettings: WalletAccountSettingsProtocol,
         cryptoType: CryptoType,
         accountSigner: SigningWrapperProtocol,
         extrinsicService: ExtrinsicServiceProtocol,
         dummySigner: IRSignatureCreatorProtocol,
         chainStorage: AnyDataProviderRepository<ChainStorageItem>,
         localStorageIdFactory: ChainStorageIdFactoryProtocol) {
        self.engine = engine
        self.requestFactory = requestFactory
        self.runtimeService = runtimeService
        self.accountSettings = accountSettings
        self.cryptoType = cryptoType
        self.accountSigner = accountSigner
        self.extrinsicService = extrinsicService
        self.dummySigner = dummySigner
        self.chainStorage = chainStorage
        self.localStorageIdFactory = localStorageIdFactory
    }

    func createGenesisHashOperation() -> BaseOperation<String> {
        createBlockHashOperation(0)
    }

    func createBlockHashOperation(_ block: UInt32) -> BaseOperation<String> {
        var currentBlock = block
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
    }

    func createFreeBalanceOperation(accountId: String, assetId: String) -> JSONRPCListOperation<BalanceInfo> {
        return JSONRPCListOperation<BalanceInfo>(engine: engine,
                                                 method: RPCMethod.freeBalance,
                                                 parameters: [accountId, assetId])
    }

    func createUsableBalanceOperation(accountId: String, assetId: String) -> JSONRPCListOperation<OrmlAccountStorage> {
        do {
            let address: AccountAddress = accountId
            return JSONRPCListOperation<OrmlAccountStorage>(
                engine: engine,
                method: RPCMethod.getStorage,
                parameters: [
                    try StorageKeyFactory().accountsKey(
                        account: address.accountId!,
                        asset: Data.sora(hex: assetId)
                    ).toHex(includePrefix: true)
                ]
            )
        } catch {
            return .init(engine: engine, method: "")
        }
    }
    
    func createActiveEraOperation() -> CompoundOperationWrapper<UInt32?> {
        do {
            let activeEraKey = try StorageKeyFactory().activeEra()
            let localKey = localStorageIdFactory.createIdentifier(for: activeEraKey)

            return chainStorage.queryStorageByKey(localKey)
        } catch {
            return  createCompoundOperation(result: .failure(error))
        }
    }
    
    func createStackingIngoOperation(accountId: Data) -> JSONRPCListOperation<JSONScaleDecodable<StakingLedger>> {
        do {
            let stackingKey = try StorageKeyFactory().stakingInfoForControllerId(accountId)
            
            return JSONRPCListOperation<JSONScaleDecodable<StakingLedger>>(
                engine: engine,
                method: RPCMethod.getStorage,
                parameters: [stackingKey.toHex()]
            )
        } catch {
            return .init(engine: engine, method: "")
        }
    }

    func createUpgradedInfoFetchOperation() -> CompoundOperationWrapper<Bool?> {
        do {
            let remoteKey = try StorageKeyFactory().updatedDualRefCount()
            let localKey = localStorageIdFactory.createIdentifier(for: remoteKey)

            return chainStorage.queryStorageByKey(localKey)

        } catch {
            return createCompoundOperation(result: .failure(error))
        }
    }

    func createAccountInfoFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<AccountInfo?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = requestFactory.queryItems(
            engine: engine,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.account
        )

        let mapOperation = ClosureOperation<AccountInfo?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createExtrinsicNonceFetchOperation(_ chain: Chain, accountId: Data? = nil) -> BaseOperation<UInt32> {
        do {
            let identifier = try (accountId ?? Data(hexStringSSF: accountSettings.accountId))

            let address = try SS58AddressFactory()
                .address(fromAccountId: identifier,
                         type: SNAddressType(chain: chain))

            return JSONRPCListOperation<UInt32>(engine: engine,
                                                method: RPCMethod.getExtrinsicNonce,
                                                parameters: [address])
        } catch {
            return createBaseOperation(result: .failure(error))
        }
    }

    func createRuntimeVersionOperation() -> BaseOperation<RuntimeVersion> {
        return JSONRPCListOperation(engine: engine, method: RPCMethod.getRuntimeVersion)
    }

    func createExtrinsicServiceOperation(closure: @escaping ExtrinsicBuilderClosure) -> BaseOperation<String> {
        let signer = accountSigner
        let service = extrinsicService

        return AwaitOperation<String> {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                service.submit(
                    closure,
                    signer: signer,
                    runningIn: .main
                ) { result, _, _ in
                    continuation.resume(with: result)
                }
            }
        }
    }

    func createExtrinsicFeeServiceOperation(asset: String,
                                            amount: BigUInt,
                                            receiver: String,
                                            chain: Chain,
                                            estimateFee: Bool? = false) -> BaseOperation<String> {
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            
            let transferCall = try callFactory.transfer(to: receiver,
                                                        asset: asset,
                                                        amount: amount)
            
            return try builder.adding(call: transferCall)
        }
        
        let service = extrinsicService

        return AwaitOperation<String> {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                service.estimateFee(closure, runningIn: .main) { result in
                    continuation.resume(with: result)
                }
            }
        }
    }

    func createCompoundOperation<T>(result: Result<T, Error>) -> CompoundOperationWrapper<T> {
        let baseOperation = createBaseOperation(result: result)
        return CompoundOperationWrapper(targetOperation: baseOperation)
    }

    func createBaseOperation<T>(result: Result<T, Error>) -> BaseOperation<T> {
        let baseOperation: BaseOperation<T> = BaseOperation()
        baseOperation.result = result
        return baseOperation
    }
}
