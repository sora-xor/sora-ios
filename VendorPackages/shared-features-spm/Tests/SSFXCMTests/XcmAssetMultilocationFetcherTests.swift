import RobinHood
import XCTest

@testable import SSFXCM

typealias OperationType = [RemoteAssetMultilocation]

final class XcmAssetMultilocationFetcherTests: XCTestCase {
    var fetcher: XcmAssetMultilocationFetching?
    var dataFetchFactory: NetworkOperationFactoryProtocolMock<[RemoteAssetMultilocation]>?
    var retryStrategy: ReconnectionStrategyProtocolMock?

    override func setUp() {
        super.setUp()

        let dataFetchFactory = NetworkOperationFactoryProtocolMock<[RemoteAssetMultilocation]>()
        dataFetchFactory.fetchDataFromReturnValue = createInitOperation()

        let retryStrategy = ReconnectionStrategyProtocolMock()

        self.dataFetchFactory = dataFetchFactory
        self.retryStrategy = retryStrategy

        fetcher = XcmAssetMultilocationFetcher(
            sourceUrl: XcmConfig.shared.tokenLocationsSourceUrl,
            dataFetchFactory: dataFetchFactory,
            retryStrategy: retryStrategy,
            operationQueue: OperationQueue()
        )
    }

    override func tearDown() {
        super.tearDown()
        fetcher = nil
        dataFetchFactory = nil
        retryStrategy = nil
    }

    func testXcmAssetMultilocationFetcherInit() {
        // arrange
        let url = XcmConfig.shared.tokenLocationsSourceUrl
        let fetchFactory = NetworkOperationFactoryProtocolMock<[RemoteAssetMultilocation]>()
        let reconnectionStrategy = ReconnectionStrategyProtocolMock()
        let queue = OperationQueue()

        fetchFactory.fetchDataFromReturnValue = createVersionedOperation()

        // act
        let assetFetcher = XcmAssetMultilocationFetcher(
            sourceUrl: url,
            dataFetchFactory: fetchFactory,
            retryStrategy: reconnectionStrategy,
            operationQueue: queue
        )

        // assert
        XCTAssertNotNil(assetFetcher)
        XCTAssertEqual(fetchFactory.fetchDataFromCallsCount, 1)
        XCTAssertTrue(fetchFactory.fetchDataFromCalled)
    }

    func testVersionedMultilocation() async throws {
        // arrange
        dataFetchFactory?.fetchDataFromReturnValue = createVersionedOperation()

        // act
        let assetMultiplication = try await fetcher?.versionedMultilocation(
            originAssetId: "0",
            destChainId: "3"
        )

        // assert
        XCTAssertEqual(assetMultiplication, TestData.multilocation)
        XCTAssertEqual(dataFetchFactory?.fetchDataFromCallsCount, 2)
        XCTAssertTrue(dataFetchFactory?.fetchDataFromCalled ?? false)
    }

    func testVersionedMultilocationWithAssetError() async throws {
        // arrange
        dataFetchFactory?.fetchDataFromReturnValue = createVersionedOperation()

        // act
        do {
            let assetMultiplication = try await fetcher?.versionedMultilocation(
                originAssetId: "1",
                destChainId: "2"
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingAssetLocationsResult.localizedDescription
            )
        }
    }

    func testVersionedMultilocationWithRetryError() async throws {
        // arrange
        let operation = createVersionedOperation()
        operation.result = .failure(XcmError.missingLocalAssetLocations)
        dataFetchFactory?.fetchDataFromReturnValue = operation
        retryStrategy?.reconnectAfterAttemptReturnValue = 0.3

        // act
        do {
            let assetMultiplication = try await fetcher?.versionedMultilocation(
                originAssetId: "1",
                destChainId: "2"
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingLocalAssetLocations.localizedDescription
            )
            XCTAssertEqual(retryStrategy?.reconnectAfterAttemptCallsCount, 1)
            XCTAssertTrue(retryStrategy?.reconnectAfterAttemptCalled ?? false)
        }
    }
}

extension XcmAssetMultilocationFetcherTests {
    enum TestData {
        static let multilocation = AssetMultilocation(
            id: "0",
            symbol: "1",
            interiors: [.onlyChild]
        )
    }

    private func createInitOperation() -> BaseOperation<[RemoteAssetMultilocation]> {
        let asset = AssetMultilocation(
            id: "1",
            symbol: "2",
            interiors: [.onlyChild]
        )

        let multilocation = RemoteAssetMultilocation(
            name: "3",
            chainId: "4",
            assets: [asset]
        )

        let operation = ClosureOperation {
            [multilocation]
        }

        return operation
    }

    private func createVersionedOperation() -> BaseOperation<[RemoteAssetMultilocation]> {
        let multilocation = RemoteAssetMultilocation(
            name: "2",
            chainId: "3",
            assets: [TestData.multilocation]
        )

        let operation = ClosureOperation {
            [multilocation]
        }

        return operation
    }
}
