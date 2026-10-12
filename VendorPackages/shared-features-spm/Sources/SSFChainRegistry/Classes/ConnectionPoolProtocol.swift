import Foundation
import SSFChainConnection
import SSFModels
import SSFUtils

public enum ConnectionPoolError: Error {
    case missingConnection
}

public protocol ConnectionPoolProtocol {
    func setupSubstrateConnection(for chain: ChainModel) async throws -> SubstrateConnection
    func getSubstrateConnection(for chainId: ChainModel.Id) async throws -> SubstrateConnection

    func setupWeb3EthereumConnection(for chain: ChainModel) async throws -> Web3EthConnection
    func getWeb3EthereumConnection(for chainId: ChainModel.Id) async throws -> Web3EthConnection
}

protocol ConnectionPoolDelegate: AnyObject {
    func webSocketDidChangeState(url: URL, state: WebSocketEngine.State)
}

public actor ConnectionPool: ConnectionPoolProtocol {
    private var autoBalancesByChainIds: [ChainModel.Id: any ChainConnectionProtocol] = [:]

    public init() {}

    // MARK: - Public methods

    public func setupSubstrateConnection(for chain: ChainModel) async throws
        -> SubstrateConnection
    {
        if let connection = try? await getSubstrateConnection(for: chain.chainId) {
            return connection
        }

        await clearUnusedConnections()

        let nodes = chain.nodes.map { $0.url }
        let autoBalance = SubstrateConnectionAutoBalance(
            urls: nodes,
            selectedUrl: chain.selectedNode?.url,
            chainId: chain.chainId
        )

        autoBalancesByChainIds[chain.chainId] = autoBalance

        return try await autoBalance.connection()
    }

    public func getSubstrateConnection(
        for chainId: ChainModel
            .Id
    ) async throws -> SubstrateConnection {
        guard let autoBalance = autoBalancesByChainIds[chainId] as? SubstrateConnectionAutoBalance else {
            throw ConnectionPoolError.missingConnection
        }
        return try await autoBalance.connection()
    }

    public func setupWeb3EthereumConnection(for chain: ChainModel) async throws
        -> Web3EthConnection
    {
        if let connection = try? await getWeb3EthereumConnection(for: chain.chainId) {
            return connection
        }

        await clearUnusedConnections()

        let autoBalance = Web3EthConnectionAutoBalance(chain: chain)

        autoBalancesByChainIds[chain.chainId] = autoBalance

        return try autoBalance.connection()
    }

    public func getWeb3EthereumConnection(
        for chainId: ChainModel
            .Id
    ) async throws -> Web3EthConnection {
        guard let autoBalance = autoBalancesByChainIds[chainId] as? Web3EthConnectionAutoBalance else {
            throw ConnectionPoolError.missingConnection
        }
        return try autoBalance.connection()
    }

    // MARK: - Private methods

    private func clearUnusedConnections() async {
        await autoBalancesByChainIds.asyncForEach { key, value in
            let isActive = await value.getActiveStatus()
            if !isActive {
                await clearAutoBalances(with: key)
            }
        }
    }

    func clearAutoBalances(with key: String) async {
        autoBalancesByChainIds[key] = nil
    }
}
