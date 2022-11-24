/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import FearlessUtils
import IrohaCrypto
import BigInt
import SoraKeystore

extension WalletNetworkFacade {
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

            let storageKeyFactory = StorageKeyFactory()
            let accountInfoKey = try storageKeyFactory.accountInfoKeyForId(accountId)
            let upgradeCheckOperation: CompoundOperationWrapper<Bool?> = CompoundOperationWrapper.createWithResult(true)
            let accountInfoOperation: CompoundOperationWrapper<AccountInfo?> = queryAccountInfoByKey(
                accountInfoKey,
                dependingOn: upgradeCheckOperation
            )

            let dependencies = assets.map({ factory.createUsableBalanceOperation(accountId: selectedAccount.address, assetId: $0.identifier) })

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

                    let balanceData = BalanceData(identifier: asset.identifier,
                                                  balance: AmountDecimal(value: context.available),
                                                  context: context.toContext())
                    return balanceData
                }

                return result
            }
            let infoDependencies = upgradeCheckOperation.allOperations + accountInfoOperation.allOperations
            dependencies.forEach { mappingOperation.addDependency($0) }
            infoDependencies.forEach { mappingOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: mappingOperation,
                                            dependencies: dependencies + infoDependencies)
        } catch {
            return CompoundOperationWrapper<[BalanceData]?>
                .createWithError(error)
        }
    }

    func queryStorageByKey<T: ScaleDecodable>(_ storageKey: Data) -> CompoundOperationWrapper<T?> {
        let identifier = localStorageIdFactory.createIdentifier(for: storageKey)
        return chainStorage.queryStorageByKey(identifier)
    }

    func queryAccountInfoByKey(
        _ storageKey: Data,
        dependingOn upgradeOperation: CompoundOperationWrapper<Bool?>
    ) -> CompoundOperationWrapper<AccountInfo?> {

        let identifier = localStorageIdFactory.createIdentifier(for: storageKey)

        let fetchOperation = chainStorage
            .fetchOperation(by: identifier,
                            options: RepositoryFetchOptions())

        guard
            let runtimeCodingService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(
                for: Chain.sora.genesisHash()
            )
        else {
            return CompoundOperationWrapper.createWithError(WalletNetworkFacadeError.missingTransferData)
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<AccountInfo?>(
            path: .account,
            data: nil
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
                let item = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                decodingOperation.data = item?.data
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)
        decodingOperation.addDependency(fetchOperation)


        let decoderOperation: ClosureOperation<AccountInfo?> = ClosureOperation {
            let item = try decodingOperation.extractResultData()
            return item!
        }

        decoderOperation.addDependency(decodingOperation)

        upgradeOperation.allOperations.forEach { decodingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: decoderOperation,
                                        dependencies: [fetchOperation, codingFactoryOperation, decodingOperation])
    }
}
