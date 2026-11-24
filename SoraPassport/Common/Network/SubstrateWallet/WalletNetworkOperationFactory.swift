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

    /// The `Tokens.Accounts` storage value of every asset in `assetIds` for one account, by asset
    /// id, read with one request.
    ///
    /// Until 2026-11-22 every asset had a request of its own: about 270 at once each time the
    /// wallet opened, each holding a thread until the node answered it, and everything else the
    /// app read at that moment (the wallet list, the home's own balances) waited for a free one.
    ///
    /// Each asset still has its own outcome, as it had with its own request:
    /// - no answer from the node (a timeout, a dropped connection): a failure for every asset,
    ///   which `WalletBalanceReading` reports as not read;
    /// - an answer that is not the storage read that was asked for (not one change set of one
    ///   block, a key that was not asked for, a key twice): a `DecodingError` for every asset,
    ///   reported as not understood;
    /// - a value that is neither text nor null: a `DecodingError` for that asset only;
    /// - a key the node left out of an otherwise sound answer: a failure for that asset only;
    /// - an account, or an asset id that is not exactly 32 bytes of plain hex, whose key cannot
    ///   be built: a failure for that asset, and no request at all when no key can be built.
    func createTokenStorageOperation(
        accountId: String,
        assetIds: [String]
    ) -> CompoundOperationWrapper<[String: Result<OrmlAccountStorage, Error>]> {
        var outcomes: [String: Result<OrmlAccountStorage, Error>] = [:]
        // Two spellings of one id (upper and lower case) are one key and get the same outcome.
        var assetsByKey: [String: [String]] = [:]
        let address: AccountAddress = accountId
        for assetId in assetIds {
            do {
                guard let publicKey = address.accountId else {
                    throw WalletNetworkOperationFactoryError.invalidContext
                }
                guard let asset = TokenStorageChanges.hash(assetId, prefixRequired: false) else {
                    throw WalletNetworkOperationFactoryError.invalidAsset
                }
                let key = try StorageKeyFactory().accountsKey(account: publicKey, asset: asset)
                    .toHex(includePrefix: true)
                assetsByKey[key, default: []].append(assetId)
            } catch {
                outcomes[assetId] = .failure(error)
            }
        }
        guard !assetsByKey.isEmpty else {
            return CompoundOperationWrapper.createWithResult(outcomes)
        }
        let request = JSONRPCOperation<[[String]], [TokenStorageChanges]>(
            engine: engine,
            method: RPCMethod.queryStorageAt,
            parameters: [assetsByKey.keys.sorted()]
        )
        let mapping = ClosureOperation<[String: Result<OrmlAccountStorage, Error>]> {
            var outcomes = outcomes
            func all(_ outcome: Result<OrmlAccountStorage, Error>) -> [String: Result<OrmlAccountStorage, Error>] {
                assetsByKey.values.joined().forEach { outcomes[$0] = outcome }
                return outcomes
            }
            let answer: [TokenStorageChanges]
            do {
                answer = try request.extractNoCancellableResultData()
            } catch {
                return all(.failure(error))
            }
            let notUnderstood = DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "not the storage read that was asked for")
            )
            // One change set of one block, and in it only keys that were asked for, each once.
            guard answer.count == 1, let set = answer.first, let changes = set.changes,
                  let block = set.block, TokenStorageChanges.hash(block, prefixRequired: true) != nil else {
                return all(.failure(notUnderstood))
            }
            var stored: [String: Result<OrmlAccountStorage, Error>] = [:]
            for change in changes {
                guard change.count == 2, case let .text(key) = change[0],
                      assetsByKey[key.lowercased()] != nil, stored[key.lowercased()] == nil else {
                    return all(.failure(notUnderstood))
                }
                switch change[1] {
                case let .text(hex): stored[key.lowercased()] = .success(OrmlAccountStorage(hex: hex))
                case .null: stored[key.lowercased()] = .success(OrmlAccountStorage(hex: nil))
                case .other: stored[key.lowercased()] = .failure(notUnderstood)
                }
            }
            for (key, assets) in assetsByKey {
                let outcome = stored[key] ?? .failure(WalletNetworkOperationFactoryError.storageNotAnswered)
                assets.forEach { outcomes[$0] = outcome }
            }
            return outcomes
        }
        mapping.addDependency(request)
        return CompoundOperationWrapper(targetOperation: mapping, dependencies: [request])
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
            guard identifier.count == 32 else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }

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

/// One change set of a `state_queryStorageAt` answer, decoded value by value, so that one value
/// of an unexpected kind is that key's problem and not the whole answer's.
struct TokenStorageChanges: Decodable {
    enum Item: Decodable {
        case text(String)
        case null
        /// Neither text nor null.
        case other

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let text = try? container.decode(String.self) {
                self = .text(text)
            } else {
                self = .other
            }
        }
    }

    let block: String?
    let changes: [[Item]]?

    /// The 32 bytes `text` spells as exactly 64 plain hex digits, with the `0x` prefix (optional
    /// unless `prefixRequired`): what a block hash and an asset id are. Nothing else is one, so
    /// a short id or one in other digits never becomes a storage key of its own.
    static func hash(_ text: String, prefixRequired: Bool) -> Data? {
        let hasPrefix = text.hasPrefix("0x")
        guard hasPrefix || !prefixRequired else { return nil }
        let digits = hasPrefix ? text.dropFirst(2) : Substring(text)
        guard digits.utf8.count == 64, digits.utf8.allSatisfy({ byte in
            (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
        }) else { return nil }
        return try? Data.sora(hex: text)
    }
}
