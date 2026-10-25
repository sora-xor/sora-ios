import Foundation
import RobinHood

public protocol LocalAssetBalanceService {
    func get(by identifier: String) async throws -> AssetBalanceInfo?
    func getAll() async throws -> [AssetBalanceInfo]
    func sync(remoteBalances: [AssetBalanceInfo]) async throws
}

public actor LocalAssetBalanceServiceDefault {
    struct Changes {
        let newOrUpdatedItems: [AssetBalanceInfo]
        let removedItems: [AssetBalanceInfo]
    }

    private let repository: AsyncAnyRepository<AssetBalanceInfo>
    private let operationManager: OperationManagerProtocol

    public init(
        repository: AsyncAnyRepository<AssetBalanceInfo>,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension LocalAssetBalanceServiceDefault: LocalAssetBalanceService {
    public func get(by identifier: String) async throws -> AssetBalanceInfo? {
        try await repository.fetch(by: identifier)
    }

    public func getAll() async throws -> [AssetBalanceInfo] {
        try await repository.fetchAll(with: RepositoryFetchOptions())
    }

    public func sync(remoteBalances: [AssetBalanceInfo]) async throws {
        try await repository.save(models: remoteBalances)
    }
}
