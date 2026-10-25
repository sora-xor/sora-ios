import XCTest

@testable import SSFXCM

final class XcmAssemblyTests: XCTestCase {
    func testCreateExtrincisServices() {
        // act
        let service = XcmAssembly.createExtrincisServices(
            fromChainData: TestData.fromChainData,
            sourceConfig: XcmConfig.shared
        )

        // assert
        XCTAssertNotNil(service)
    }
}

extension XcmAssemblyTests {
    enum TestData {
        static let fromChainData = XcmAssembly.FromChainData(
            chainId: "1",
            cryptoType: .ed25519,
            chainMetadata: nil,
            accountId: Data(),
            signingWrapperData: .init(
                publicKeyData: Data(),
                secretKeyData: Data()
            ),
            chainType: .substrate
        )
    }
}
