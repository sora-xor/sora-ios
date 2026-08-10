import XCTest
@testable import SoraPassport
import SSFUtils

final class AssetsInfoProviderTests: XCTestCase {

    var provider: AssetsInfoProvider!

    override func setUpWithError() throws {
        let url: URL = URL(string: "wss://mof2.sora.org")!
        let logger = Logger.shared
        let engine = WebSocketEngine(connectionName: nil, url: url, logger: logger)

        provider = AssetsInfoProvider(engine: engine, storageKeyFactory: StorageKeyFactory())
    }

    func testLoadKeys() {
        //given

        //when
        provider.loadAssetsInfoKeys {}

        //then
        Logger.shared.debug("Asset info keys loaded")
        XCTAssert(provider.keys.count > 0)
    }

    func testLoadAssetInfo() {
        //given

        //when
        var assetsInfo: [AssetInfo] = []
        provider.load(completion: { result in
            assetsInfo = result
        })

        //then
        Logger.shared.debug("Asset info catalog loaded")
        XCTAssert(assetsInfo.count > 0)
        XCTAssertEqual(assetsInfo.count, provider.keys.count)
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
            XCTAssertEqual(assetInfo.underlyingValue?.name, "SORA")
            XCTAssertEqual(assetInfo.underlyingValue?.precision, 18)
            XCTAssertEqual(assetInfo.underlyingValue?.isMintable, true)
            Logger.shared.debug("Asset info response received")

        } catch {
            XCTFail("Asset info request failed")
        }
    }
}
