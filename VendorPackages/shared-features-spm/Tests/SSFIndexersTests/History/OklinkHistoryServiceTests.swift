import MocksBasket
import SSFIndexers
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFOklinkIndexer

final class OklinkHistoryServiceTests: BaseHistoryServiceTestCase {
    private var expectedResponse: OklinkHistoryResponse {
        get throws {
            try getResponse(file: "oklink")
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
            blockExplorerType: .oklink,
            assetSymbol: "eth",
            precision: 1,
            ethereumType: nil,
            contractaddress: "13"
        )

        let history = try await historyService?.fetchTransactionHistory(
            chainAsset: chainAsset,
            address: "0x85c6627c4ed773cb7c32644b041f58a058b00d30",
            filters: [],
            pagination: Pagination(count: 100)
        )
        XCTAssertEqual(history?.transactions.count, 1)
    }

    private func setupServices() throws {
        guard historyService == nil || networkWorker == nil else {
            return
        }
        let networkWorker = NetworkWorkerMock<OklinkHistoryResponse>()
        networkWorker.performRequestWithReturnValue = try expectedResponse
        super.networkWorker = networkWorker
        let service = OklinkHistoryService(networkWorker: networkWorker)
        super.historyService = service
    }
}
