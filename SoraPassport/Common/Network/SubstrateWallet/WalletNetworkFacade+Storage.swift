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

import Foundation

import RobinHood
import SSFUtils
import IrohaCrypto
import BigInt
import SoraKeystore

extension WalletNetworkFacade {
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
    
    func fetchBalanceInfoForAssets(_ assets: [WalletAsset])
        -> CompoundOperationWrapper<[BalanceData]?> {
        //swiftlint:disable force_cast
        let factory = nodeOperationFactory as! WalletNetworkOperationFactory
        //swiftlint:enable force_cast
        do {

            guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
                return CompoundOperationWrapper<[BalanceData]?>.createWithResult(.none)
            }
            let selectedConnectionType = selectedAccount.addressType
            let accountId = try SS58AddressFactory().accountId(
                fromAddress: selectedAccount.address,
                type: selectedConnectionType
            )

            let accountInfoOperation: CompoundOperationWrapper<AccountInfo?> = createAccountInfoFetchOperation(accountId)

            let dependencies = assets.map({ factory.createUsableBalanceOperation(accountId: selectedAccount.address, assetId: $0.identifier) })
            
            let eraOperation = factory.createActiveEraOperation()
            let stackingInfoOperation = factory.createStackingIngoOperation(accountId: accountId)
            
            let mappingOperation = ClosureOperation<[BalanceData]?> {

                let result = dependencies.map { operation -> BalanceData in
                    let assetNetworkId = operation.parameters?.last
                    guard let asset = assets.first(where: { assetNetworkId?.contains($0.identifier.dropFirst(2)) ?? false }) else {
                        return .init(identifier: WalletAsset.dummyAsset.identifier, balance: .init(value: 0))
                    }
                    let balances = try? operation.extractResultData()?.underlyingValue

                    let free: BigUInt
                    let reserved: BigUInt
                    let miscFrozen: BigUInt
                    let feeFrozen: BigUInt

                    if asset.identifier == WalletAssetId.xor.rawValue {
                        let info = try? accountInfoOperation.targetOperation.extractNoCancellableResultData()
                        free = info?.data.free ?? 0
                        reserved = info?.data.reserved ?? 0
                        miscFrozen = info?.data.miscFrozen ?? 0
                        feeFrozen = info?.data.feeFrozen ?? 0
                    } else {
                        free = balances?.free.value ?? 0
                        reserved = balances?.reserved.value ?? 0
                        miscFrozen = 0
                        feeFrozen = balances?.frozen.value ?? 0
                    }

                    var context: BalanceContext = BalanceContext(context: [:])
                    let accountData = AccountData(
                        free: free,
                        reserved: reserved,
                        miscFrozen: miscFrozen,
                        feeFrozen: feeFrozen
                    )
                    context = context.byChangingAccountInfo(accountData, precision: asset.precision)
                    
                    if asset.identifier == WalletAssetId.xor.rawValue,
                       let eraInfo = try? eraOperation.targetOperation.extractNoCancellableResultData(),
                       let stackingInfo = try? stackingInfoOperation.extractNoCancellableResultData().underlyingValue {
                        context = context.byChangingStakingInfo(stackingInfo, activeEra: eraInfo, precision: asset.precision)
                    }
                    

                    let balanceData = BalanceData(identifier: asset.identifier,
                                                  balance: AmountDecimal(value: context.available),
                                                  context: context.toContext())
                    return balanceData
                }

                return result
            }
            let infoDependencies = accountInfoOperation.allOperations
            infoDependencies.forEach { operation in
                mappingOperation.addDependency(operation)
            }
            
            dependencies.forEach { operation in
                mappingOperation.addDependency(operation)
            }

            return CompoundOperationWrapper(targetOperation: mappingOperation,
                                            dependencies: dependencies + infoDependencies + eraOperation.allOperations + [stackingInfoOperation])
        } catch {
            return CompoundOperationWrapper<[BalanceData]?>
                .createWithError(error)
        }
    }

    func queryStorageByKey<T: ScaleDecodable>(_ storageKey: Data) -> CompoundOperationWrapper<T?> {
        let identifier = localStorageIdFactory.createIdentifier(for: storageKey)
        return chainStorage.queryStorageByKey(identifier)
    }
}
