import Foundation
import RobinHood
import SSFBalances

public typealias AssetBalanceRepository = AsyncCoreDataRepositoryDefault<
    AssetBalanceInfo,
    CDAssetBalance
>

public protocol AssetBalanceRepositoryAssembly {
    func createRepository() throws -> AssetBalanceRepository
}

public final class AssetBalanceRepositoryAssemblyDefault: AssetBalanceRepositoryAssembly {
    public init() {}

    public func createRepository() throws -> AssetBalanceRepository {
        AssetBalanceDataStorageFacade().createRepository()
    }
}
