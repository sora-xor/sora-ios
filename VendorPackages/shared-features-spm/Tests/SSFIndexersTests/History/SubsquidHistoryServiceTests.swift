import MocksBasket
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFSubsquidIndexer

final class SubsquidHistoryServiceTests: BaseHistoryServiceTestCase {
    private var expectedResponse: GraphQLResponse<SubsquidHistoryResponse> {
        get throws {
            try getResponse(file: "subsquid")
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
            assetSymbol: "dot",
            precision: 10,
            ethereumType: nil,
            contractaddress: nil
        )

        let history = try await historyService?.fetchTransactionHistory(
            chainAsset: chainAsset,
            address: "12uM6CcbUTgXVn9pMmEjz4VfSqPucS2hPpnfgiiK95Pxaram",
            filters: [.init(type: .transfer)],
            pagination: Pagination(count: 100)
        )
        XCTAssertEqual(history?.transactions.count, 18)
    }

    private func setupServices() throws {
        guard historyService == nil || networkWorker == nil else {
            return
        }
        let networkWorker = NetworkWorkerMock<GraphQLResponse<SubsquidHistoryResponse>>()
        networkWorker.performRequestWithReturnValue = try expectedResponse
        super.networkWorker = networkWorker

        let repository = try IndexersRepositoryAssemblyDefault().createRepository()
        let txStorage = AsyncAnyRepository(repository)

        let service = SubsquidHistoryService(
            txStorage: txStorage,
            networkWorker: networkWorker
        )
        super.historyService = service
    }
}
