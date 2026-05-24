import MocksBasket
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFSubqueryIndexer

final class SubqueryHistoryServiceTests: BaseHistoryServiceTestCase {
    private var expectedResponse: GraphQLResponse<SubqueryHistoryData> {
        get throws {
            try getResponse(file: "subquery")
        }
    }

    override func setUpWithError() throws {
        try setupServices()
    }

    override func tearDownWithError() throws {
        networkWorker = nil
        historyService = nil
    }

    func test() async throws {
        let chainAsset = chainAsset(
            blockExplorerType: .subsquid,
            assetSymbol: "val",
            precision: 18,
            ethereumType: nil,
            contractaddress: nil
        )

        let history = try await historyService?.fetchTransactionHistory(
            chainAsset: chainAsset,
            address: "cnTPdZkShU3Nc8inmZsQnBiCLRVp9CT2xv1jeXZeuvjNGP8cj",
            filters: [.init(type: .transfer)],
            pagination: Pagination(count: 100)
        )
        XCTAssertEqual(history?.transactions.count, 100)
    }

    private func setupServices() throws {
        guard historyService == nil || networkWorker == nil else {
            return
        }
        let networkWorker = NetworkWorkerMock<GraphQLResponse<SubqueryHistoryData>>()
        networkWorker.performRequestWithReturnValue = try expectedResponse
        super.networkWorker = networkWorker

        let repository = try IndexersRepositoryAssemblyDefault().createRepository()
        let txStorage = AsyncAnyRepository(repository)

        let runtimeService = RuntimeProviderProtocolMock()
        runtimeService.fetchCoderFactoryReturnValue = RuntimeCoderFactoryProtocolMock()

        let chainRegistry = ChainRegistryProtocolMock()
        chainRegistry
            .getRuntimeProviderChainIdUsedRuntimePathsRuntimeItemReturnValue = runtimeService
        let service = SubqueryHistoryService(
            txStorage: txStorage,
            chainRegistry: chainRegistry,
            networkWorker: networkWorker
        )
        super.historyService = service
    }
}
