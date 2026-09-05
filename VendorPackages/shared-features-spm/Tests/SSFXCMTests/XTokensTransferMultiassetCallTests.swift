import BigInt
import SSFModels
import XCTest

@testable import SSFXCM

final class XTokensTransferMultiassetCallTests: XCTestCase {
    func testXTokensTransferMultiassetCallInit() {
        // arrange
        let asset: XcmVersionedMultiAsset = .V1(.init(
            multilocation: .init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            ),
            amount: BigUInt()
        ))
        let dest: XcmVersionedMultiLocation = .V1(.init(
            parents: 0,
            interior: .init(items: [.onlyChild])
        ))
        let destWeightLimit: XcmWeightLimit = .unlimited
        let destWeightIsPrimitive = true
        let destWeight = BigUInt()

        // act
        let call = XTokensTransferMultiassetCall(
            asset: asset,
            dest: dest,
            destWeightLimit: destWeightLimit,
            destWeightIsPrimitive: destWeightIsPrimitive,
            destWeight: destWeight
        )

        // assert
        XCTAssertEqual(call.asset, asset)
        XCTAssertEqual(call.dest, dest)
        XCTAssertEqual(call.destWeightLimit, destWeightLimit)
        XCTAssertEqual(call.destWeightIsPrimitive, destWeightIsPrimitive)
        XCTAssertEqual(call.destWeight, destWeight)
    }

    func testEncode() throws {
        // arrange
        let asset: XcmVersionedMultiAsset = .V1(.init(
            multilocation: .init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            ),
            amount: BigUInt()
        ))
        let dest: XcmVersionedMultiLocation = .V1(.init(
            parents: 0,
            interior: .init(items: [.onlyChild])
        ))
        let destWeightLimit: XcmWeightLimit = .unlimited
        let destWeightIsPrimitive = true
        let destWeight = BigUInt()
        let call = XTokensTransferMultiassetCall(
            asset: asset,
            dest: dest,
            destWeightLimit: destWeightLimit,
            destWeightIsPrimitive: destWeightIsPrimitive,
            destWeight: destWeight
        )

        // act
        let encodedData = try JSONEncoder().encode(call)

        // assert
        XCTAssertEqual(encodedData.count, TestData.callData?.count)
    }
}

extension XTokensTransferMultiassetCallTests {
    enum TestData {
        static let callData = """
        {"destWeight":"0","asset":["V1",{"id":["Concrete",{"parents":"0","interior":["X1",["OnlyChild",null]]}],"fun":["Fungible","0"]}],"dest":["V1",{"interior":["X1",["OnlyChild",null]],"parents":"0"}]}
        """.data(using: .utf8)
    }
}
