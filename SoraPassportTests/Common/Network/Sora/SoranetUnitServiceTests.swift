/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport

class SoranetUnitServiceTests: NetworkBaseTests {

    func testWithdrawProof() throws {
        // given

        let transactionHash = try NSData(hexString: "5A7E792AA6FCF84F566EA0ECFC969DD372A0E45C3316C5CE9F064DE05E51D67E")
        let info = WithdrawProofInfo(accountId: "did_sora_3ddc88245ab8a058442e@sora",
                                     intentionHash: transactionHash as Data)

        let soranetUnit = ApplicationConfig.shared.defaultSoranetUnit

        let soranetService = SoranetUnitService(unit: soranetUnit,
                                                operationFactory: SoranetUnitOperationFactory())

        // when

        WithdrawProofFetchMock.register(mock: .success, soranetUnit: soranetUnit)

        let expectation = XCTestExpectation()

        _ = try soranetService.fetchWithdrawProof(for: info, runCompletionIn: .main) { optionalResult in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult else {
                XCTFail("Unexpected empty result")
                return
            }

            switch result {
            case .success(let proofData):
                XCTAssertNotNil(proofData)
            case .failure(let error):
                XCTFail("Unexpected error \(error)")
            }
        }

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

}
