/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport

class ProjectUnitInformationServiceTests: NetworkBaseTests {
    var service: ProjectUnitService!

    override func setUp() {
        super.setUp()

        service = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        service.requestSigner = createDummyRequestSigner()
    }

    func testAnnouncementEmptySuccess() {
        // given
        AnnouncementFetchMock.register(mock: .successEmpty, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchAnnouncement(runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success(let announcement) = result else {
                XCTFail()
                return
            }

            XCTAssertNil(announcement)
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testHelpSuccess() {
        // given
        HelpFetchMock.register(mock: .success,
                               projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchHelp(runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testCurrencySuccess() {
        // given
        CurrencyFetchMock.register(mock: .success,
                               projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchCurrency(runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

}
