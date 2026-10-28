import XCTest
@testable import SoraPassport
import SSFUtils

final class AssetsInfoProviderTests: XCTestCase {

    var engine: WebSocketEngine!
    var provider: AssetsInfoProvider!

    override func setUpWithError() throws {
        let url: URL = URL(string: "wss://mof2.sora.org")!
        let logger = Logger.shared
        let engine = WebSocketEngine(connectionName: nil, url: url, logger: logger)
        self.engine = engine

        provider = AssetsInfoProvider(connection: { engine }, storageKeyFactory: StorageKeyFactory())
    }

    override func tearDown() {
        provider?.cancel()
        provider = nil
        engine = nil
    }

    func testLoadAssetInfo() {
        //given
        let loaded = expectation(description: "asset list")

        //when
        var assetsInfo: [AssetInfo] = []
        provider.load(completion: { result in
            assetsInfo = result
            loaded.fulfill()
        })

        //then
        wait(for: [loaded], timeout: 120)
        Logger.shared.debug("Asset info catalog loaded")
        XCTAssert(assetsInfo.count > 0)
    }

    func testLoadAssetInfoByKey() {
        let url: URL = URL(string: "wss://mof2.sora.org")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()
        let engine = WebSocketEngine(connectionName: nil, url: url, logger: logger)
        let xorKey = "0x682a59d51ab9e48a8c8cc418ff9708d2f5b4fc54f4471c9a65803b7767ecc9ff123c6b93355876da0200000000000000000000000000000000000000000000000000000000000000"
        let operation = JSONRPCOperation<[String], JSONScaleDecodable<AssetInfoDto>>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorage,
            parameters: [xorKey])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            guard let assetInfo = try operation.extractResultData()
            else {
                XCTFail("No assetInfo")
                return
            }
            XCTAssertEqual(assetInfo.underlyingValue?.symbol, "XOR")
            XCTAssertEqual(assetInfo.underlyingValue?.name, "XOR")
            XCTAssertEqual(assetInfo.underlyingValue?.precision, 18)
            XCTAssertEqual(assetInfo.underlyingValue?.isMintable, true)
            Logger.shared.debug("Asset info response received")

        } catch {
            XCTFail("Asset info request failed")
        }
    }
}
