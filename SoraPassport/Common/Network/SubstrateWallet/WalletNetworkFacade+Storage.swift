import Foundation
import CommonWallet
import RobinHood
import FearlessUtils
import IrohaCrypto

extension WalletNetworkFacade {
    func fetchBalanceInfoForAssets(_ assets: [WalletAsset])
        -> CompoundOperationWrapper<[BalanceData]?> {
        //swiftlint:disable force_cast
        let factory = nodeOperationFactory as! WalletNetworkOperationFactory
        //swiftlint:enable force_cast
        do {
            let accountId = try Data(hexString: accountSettings.accountId)
            let storageKeyFactory = StorageKeyFactory()

            let accountInfoKey = try storageKeyFactory.accountInfoKeyForId(accountId)

            let address = try? SS58AddressFactory()
                .address(fromAccountId: Data(hexString: accountSettings.accountId),
                         type: SNAddressType(chain: .sora))

            let upgradeCheckOperation: CompoundOperationWrapper<Bool?> = CompoundOperationWrapper.createWithResult(true)
            let accountInfoOperation: CompoundOperationWrapper<AccountInfo?> =
                queryAccountInfoByKey(accountInfoKey, dependingOn: upgradeCheckOperation)

            let dependencies = assets.map({  factory.createUsableBalanceOperation(accountId: address!, assetId: $0.identifier) })

            let mappingOperation = ClosureOperation<[BalanceData]?> {

                let info = try accountInfoOperation.targetOperation.extractNoCancellableResultData()

                let result = try dependencies.map { operation -> BalanceData in
                    let assetNetworkId = operation.parameters?.last
                    let asset = assets.first { $0.identifier == assetNetworkId }
                    let balance = try? operation.extractResultData()

                    var context: BalanceContext = BalanceContext(context: [:])
                    let accountData = AccountData(free: balance?.balance ?? 0)
                    context = context.byChangingAccountInfo(accountData, precision: asset!.precision)

                    let balanceData = BalanceData(identifier: asset!.identifier,
                                                  balance: AmountDecimal(value: context.total),
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

    func queryAccountInfoByKey(_ storageKey: Data,
                               dependingOn upgradeOperation: CompoundOperationWrapper<Bool?>) ->
    CompoundOperationWrapper<AccountInfo?> {
        let identifier = localStorageIdFactory.createIdentifier(for: storageKey)

        let fetchOperation = chainStorage
            .fetchOperation(by: identifier,
                            options: RepositoryFetchOptions())

        let decoderOperation: ClosureOperation<AccountInfo?> = ClosureOperation {
            let item = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let data = item?.data else {
                return nil
            }

            let decoder = try ScaleDecoder(data: data)

            return try AccountInfo(scaleDecoder: decoder)
        }

        decoderOperation.addDependency(fetchOperation)

        upgradeOperation.allOperations.forEach { decoderOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: decoderOperation,
                                        dependencies: [fetchOperation])
    }
}
