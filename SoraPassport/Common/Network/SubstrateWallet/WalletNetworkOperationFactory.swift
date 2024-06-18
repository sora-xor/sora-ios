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

import BigInt

import SSFUtils
import Foundation
import IrohaCrypto
import RobinHood
import SSFModels
import SSFStorageQueryKit

final class WalletNetworkOperationFactory {
    let accountSettings: WalletAccountSettingsProtocol
    let engine: JSONRPCEngine
    let requestFactory: StorageRequestFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let accountSigner: IRSignatureCreatorProtocol
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
         accountSigner: IRSignatureCreatorProtocol,
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

    func createUsableBalanceOperation(accountId: String, assetId: String) -> JSONRPCListOperation<JSONScaleDecodable<OrmlAccountData>> {
        do {
            let address: AccountAddress = accountId
            return JSONRPCListOperation<JSONScaleDecodable<OrmlAccountData>>(
                engine: engine,
                method: RPCMethod.getStorage,
                parameters: [
                    try StorageKeyFactory().accountsKey(
                        account: address.accountId!,
                        asset: Data(hex: assetId)
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

        // swiftlint:disable force_cast
        let signer = accountSigner as! SigningWrapperProtocol
        // swiftlint:enable force_cast

        let operation = BaseOperation<String>()
        operation.configurationBlock = { [weak self] in
            let semaphore = DispatchSemaphore(value: 0)

            self?.extrinsicService.submit(closure, signer: signer, watch: false, runningIn: .main) { [operation] result, _, _ in
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
        
        let operation = BaseOperation<String>()
        
        operation.configurationBlock = {
            let semaphore = DispatchSemaphore(value: 0)
            
            self.extrinsicService.estimateFee(closure, runningIn: .main) { [operation] result in
                semaphore.signal()
                switch result {
                case let .success(info):
                    operation.result = .success(info)
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
