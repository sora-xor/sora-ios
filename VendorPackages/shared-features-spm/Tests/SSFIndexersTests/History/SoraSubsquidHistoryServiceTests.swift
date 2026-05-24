import MocksBasket
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFSoraSubsquidIndexer

final class SoraSubsquidHistoryServiceTests: BaseHistoryServiceTestCase {
    private var expectedResponse: GraphQLResponse<SoraSubsquidHistoryConnectionResponse> {
        get throws {
            try getResponse(file: "soraSubsquid")
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
            blockExplorerType: .sora,
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
        let networkWorker =
            NetworkWorkerMock<GraphQLResponse<SoraSubsquidHistoryConnectionResponse>>()
        networkWorker.performRequestWithReturnValue = try expectedResponse
        super.networkWorker = networkWorker

        let repository = try IndexersRepositoryAssemblyDefault().createRepository()
        let txStorage = AsyncAnyRepository(repository)

        let service = SoraSubsquidHistoryService(
            txStorage: txStorage,
            networkWorker: networkWorker
        )
        super.historyService = service
    }
}
