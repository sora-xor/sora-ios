import MocksBasket
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFGiantsquidIndexer

final class GiantsquidHistoryServiceTests: BaseHistoryServiceTestCase {
    override func setUpWithError() throws {
        try setupServices()
    }

    override func tearDownWithError() throws {
        networkWorker = nil
        historyService = nil
    }

    func test() async throws {
        let chainAsset = chainAsset(
            blockExplorerType: .giantsquid,
            assetSymbol: "glmr",
            precision: 18,
            ethereumType: nil,
            contractaddress: nil
        )

        let history = try await historyService?.fetchTransactionHistory(
            chainAsset: chainAsset,
            address: "0x599dc6fd485e0ed55c1bcc7d8ae02edaf7be4f4e",
            filters: [.init(type: .transfer)],
            pagination: Pagination(count: 100)
        )
        XCTAssertEqual(history?.transactions.count, 47)
    }

    private func setupServices() throws {
        let networkWorker = NetworkWorkerMock<GraphQLResponse<GiantsquidResponseData>>()
        let value: GraphQLResponse<GiantsquidResponseData> = try getResponse(file: "giantsquid")
        networkWorker.performRequestWithReturnValue = value
        super.networkWorker = networkWorker

        let repository = try IndexersRepositoryAssemblyDefault().createRepository()
        let txStorage = AsyncAnyRepository(repository)

        let service = GiantsquidHistoryService(
            txStorage: txStorage,
            networkWorker: networkWorker
        )
        super.historyService = service
    }
}
