import Foundation
import RobinHood
import SSFModels

public protocol LocalChainModelService: Actor {
    func getAll() async throws -> [ChainModel]
    func getChain(by chainId: String) async throws -> ChainModel?
    func sync(chainModel: [ChainModel]) async throws
    func sync(chainModel: [ChainModel], deleteIds: [String]) async throws
}

public actor LocalChainModelServiceDefault: LocalChainModelService {
    private let repository: AsyncAnyRepository<ChainModel>

    public init(repository: AsyncAnyRepository<ChainModel>) {
        self.repository = repository
    }

    public func getAll() async throws -> [ChainModel] {
        try await repository.fetchAll(with: RepositoryFetchOptions())
    }

    public func getChain(by chainId: String) async throws -> ChainModel? {
        try await repository.fetch(by: chainId, options: RepositoryFetchOptions())
    }

    public func sync(chainModel: [ChainModel]) async throws {
        try await repository.save(models: chainModel)
    }

    public func sync(chainModel: [ChainModel], deleteIds: [String]) async throws {
        await repository.save(models: chainModel, deleteIds: deleteIds)
    }
}
