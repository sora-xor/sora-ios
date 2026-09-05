import MocksBasket
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFReefIndexer

final class ReefSubsquidHistoryServiceTests: BaseHistoryServiceTestCase {
    private var expectedResponse: GraphQLResponse<ReefResponseData> {
        get throws {
            try getResponse(file: "reefSubsquid")
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
            blockExplorerType: .reef,
            assetSymbol: "reef",
            precision: 18,
            ethereumType: nil,
            contractaddress: nil
        )

        let history = try await historyService?.fetchTransactionHistory(
            chainAsset: chainAsset,
            address: "5GecoStYi2bHzKz6LwE2LWa8MWJxaZYAGjx2WeH8r4RTnQ6e",
            filters: [.init(type: .transfer)],
            pagination: Pagination(count: 100)
        )
        XCTAssertEqual(history?.transactions.count, 11)
    }

    private func setupServices() throws {
        guard historyService == nil || networkWorker == nil else {
            return
        }
        let networkWorker = NetworkWorkerMock<GraphQLResponse<ReefResponseData>>()
        networkWorker.performRequestWithReturnValue = try expectedResponse
        super.networkWorker = networkWorker

        let repository = try IndexersRepositoryAssemblyDefault().createRepository()
        let txStorage = AsyncAnyRepository(repository)

        let service = ReefSubsquidHistoryService(
            txStorage: txStorage,
            networkWorker: networkWorker
        )
        super.historyService = service
    }
}
