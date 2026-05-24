import CoreData
import Foundation
import RobinHood
import SSFModels

public final class MetaAccountMapper {
    public var entityIdentifierFieldName: String { #keyPath(CDMetaAccount.metaId) }

    public typealias DataProviderModel = MetaAccountModel
    public typealias CoreDataEntity = CDMetaAccount

    public init() {}
}

extension MetaAccountMapper: CoreDataMapperProtocol {
    public func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let chainAccounts: [ChainAccountModel] = try entity.chainAccounts?.compactMap { entity in
            guard let chainAccontEntity = entity as? CDChainAccount else {
                return nil
            }

            let ethereumBased = chainAccontEntity.ethereumBased

            let accountId = try Data(hexStringSSF: chainAccontEntity.accountId!)
            return ChainAccountModel(
                chainId: chainAccontEntity.chainId!,
                accountId: accountId,
                publicKey: chainAccontEntity.publicKey!,
                cryptoType: UInt8(bitPattern: Int8(chainAccontEntity.cryptoType)),
                ethereumBased: ethereumBased
            )
        } ?? []

        let substrateAccountId = try Data(hexStringSSF: entity.substrateAccountId!)
        let ethereumAddress = try entity.ethereumAddress.map { try Data(hexStringSSF: $0) }
        let assetFilterOptions = entity.assetFilterOptions as? [String]
        let enabledAssetIds: Set<String>? = entity.enabledAssetIds as? Set<String>

        var favouriteChainIds: [String] = []
        if let entityFavouriteChainIds = entity.favouriteChainIds {
            favouriteChainIds = (entityFavouriteChainIds as? [String]) ?? []
        }

        return DataProviderModel(
            metaId: entity.metaId!,
            name: entity.name!,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: UInt8(bitPattern: Int8(entity.substrateCryptoType)),
            substratePublicKey: entity.substratePublicKey!,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: entity.ethereumPublicKey,
            chainAccounts: Set(chainAccounts),
            assetKeysOrder: entity.assetKeysOrder as? [String],
            assetFilterOptions: assetFilterOptions?.compactMap { FilterOption(rawValue: $0) } ?? [],
            canExportEthereumMnemonic: entity.canExportEthereumMnemonic,
            unusedChainIds: entity.unusedChainIds as? [String],
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: entity.networkManagmentFilter,
            enabledAssetIds: enabledAssetIds ?? [],
            zeroBalanceAssetsHidden: entity.zeroBalanceAssetsHidden,
            hasBackup: entity.hasBackup,
            favouriteChainIds: favouriteChainIds
        )
    }

    public func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        let assetFilterOptions = model.assetFilterOptions.map(\.rawValue) as? NSArray ?? []
        entity.metaId = model.metaId
        entity.name = model.name
        entity.substrateAccountId = model.substrateAccountId.toHex()
        entity.substrateCryptoType = Int16(bitPattern: UInt16(model.substrateCryptoType))
        entity.substratePublicKey = model.substratePublicKey
        entity.ethereumPublicKey = model.ethereumPublicKey
        entity.ethereumAddress = model.ethereumAddress?.toHex()
        entity.assetKeysOrder = model.assetKeysOrder as? NSArray
        entity.canExportEthereumMnemonic = model.canExportEthereumMnemonic
        entity.unusedChainIds = model.unusedChainIds as? NSArray
        entity.assetFilterOptions = assetFilterOptions
        entity.networkManagmentFilter = model.networkManagmentFilter
        entity.zeroBalanceAssetsHidden = model.zeroBalanceAssetsHidden
        entity.hasBackup = model.hasBackup
        entity.favouriteChainIds = model.favouriteChainIds as NSArray
        entity.enabledAssetIds = model.enabledAssetIds as NSSet

        for chainAccount in model.chainAccounts {
            var chainAccountEntity = entity.chainAccounts?.first {
                if let entity = $0 as? CDChainAccount,
                   entity.chainId == chainAccount.chainId
                {
                    return true
                } else {
                    return false
                }
            } as? CDChainAccount

            if chainAccountEntity == nil {
                let newEntity = CDChainAccount(context: context)
                entity.addToChainAccounts(newEntity)
                chainAccountEntity = newEntity
            }

            chainAccountEntity?.accountId = chainAccount.accountId.toHex()
            chainAccountEntity?.chainId = chainAccount.chainId
            chainAccountEntity?.cryptoType = Int16(bitPattern: UInt16(chainAccount.cryptoType))
            chainAccountEntity?.publicKey = chainAccount.publicKey
            chainAccountEntity?.ethereumBased = chainAccount.ethereumBased
        }

        updatedEntityCurrency(for: entity, from: model, context: context)
    }

    private func updatedEntityCurrency(
        for _: CoreDataEntity,
        from model: DataProviderModel,
        context: NSManagedObjectContext
    ) {
        let currencyEntity = CDCurrency(context: context)
        currencyEntity.id = model.selectedCurrency.id
        currencyEntity.name = model.selectedCurrency.name
        currencyEntity.symbol = model.selectedCurrency.symbol
        currencyEntity.icon = model.selectedCurrency.icon
        currencyEntity.isSelected = model.selectedCurrency.isSelected ?? false

//        entity.selectedCurrency = currencyEntity
    }
}
