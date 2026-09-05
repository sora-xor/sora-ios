import MocksBasket
import SSFIndexers
import SSFModels
import SSFNetwork
import XCTest

@testable import SSFEtherscanIndexer

final class EtherscanHistoryTests: BaseHistoryServiceTestCase {
    override func tearDownWithError() throws {
        networkWorker = nil
        historyService = nil
    }

    func testTxlist() async throws {
        try setupServicesWith(response: "etherscanTxlist")
        let chainAsset = chainAsset(
            blockExplorerType: .etherscan,
            assetSymbol: "eth",
            precision: 18,
            ethereumType: .normal,
            contractaddress: nil
        )

        let history = try await historyService?.fetchTransactionHistory(
            chainAsset: chainAsset,
            address: "0xa150ea05b1a515433a6426f309ab1bc5dc62a014",
            filters: [],
            pagination: Pagination(count: 100)
        )
        XCTAssertEqual(history?.transactions.count, 10)
    }

    func testTokentx() async throws {
        try setupServicesWith(response: "etherscanTokentx")
        let chainAsset = chainAsset(
            blockExplorerType: .etherscan,
            assetSymbol: "eth",
            precision: 18,
            ethereumType: .erc20,
            contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"
        )

        let history = try await historyService?.fetchTransactionHistory(
            chainAsset: chainAsset,
            address: "0xa150ea05b1a515433a6426f309ab1bc5dc62a014",
            filters: [],
            pagination: Pagination(count: 100)
        )
        XCTAssertEqual(history?.transactions.count, 100)
    }

    private func setupServicesWith(response: String) throws {
        let networkWorker = NetworkWorkerMock<EtherscanHistoryResponse>()
        let value: EtherscanHistoryResponse = try getResponse(file: response)
        networkWorker.performRequestWithReturnValue = value
        super.networkWorker = networkWorker
        let service = EtherscanHistoryService(networkWorker: networkWorker)
        super.historyService = service
    }
}
