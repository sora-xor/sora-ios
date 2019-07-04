/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport
import FireMock

class DecentralizedResolverNetworkTests: NetworkBaseTests {
    var service: DecentralizedResolverService!

    override func setUp() {
        super.setUp()

        let serviceUrl = URL(string: ApplicationConfig.shared.didResolverUrl)!
        service = DecentralizedResolverService(url: serviceUrl)
    }

    func testFetchDecentralizedDocument() {
        // given
        DecentralizedDocumentFetchMock.register(mock: .success)

        let expectation = XCTestExpectation()

        service.fetchDecentralizedDocument(decentralizedId: Constants.dummyDid,
                                           runIn: .main) { (result) in

                                            defer {
                                                expectation.fulfill()
                                            }

                                            guard let existingResult = result else {
                                                XCTFail()
                                                return
                                            }

                                            switch existingResult {
                                            case .success:
                                                break
                                            default:
                                                XCTFail()
                                            }
        }

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testCreateDecentralizedDocument() {
        // given
        DecentralizedDocumentCreateMock.register(mock: .success)

        let expectation = XCTestExpectation()

        service.create(document: createDummyDecentralizedDocument(),
                       runIn: .main) { (result) in

                        defer {
                            expectation.fulfill()
                        }

                        guard let existingResult = result else {
                            XCTFail()
                            return
                        }

                        switch existingResult {
                        case .success:
                            break
                        default:
                            XCTFail()
                        }
        }

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }
}
