/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport

class NotificationUnitServiceTests: NetworkBaseTests {
    var service: NotificationUnitService!

    override func setUp() {
        super.setUp()

        service = NotificationUnitService(unit: ApplicationConfig.shared.defaultNotificationUnit,
                                          requestSigner: createDummyRequestSigner())
    }

    func testRegistration() {
        // given
        NotificationRegisterMock.register(mock: .success, notificationUnit: service.unit)

        let expectation = XCTestExpectation()

        // when
        let registrationInfo = NotificationUserInfo(tokens: [Constants.dummyPushToken],
                                                    allowedDecentralizedIds: [Constants.dummyDid])

        let operation = try? service.registerUser(with: registrationInfo,
                                                  runCompletionIn: .main) { (optionalResult) in
                                                    defer {
                                                        expectation.fulfill()
                                                    }

                                                    guard let result = optionalResult else {
                                                        XCTFail()
                                                        return
                                                    }

                                                    guard case .success = result else {
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

    func testTokenExchangeSuccess() {
        // given
        NotificationTokenExchangeMock.register(mock: .success, notificationUnit: service.unit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.exchangeTokens(with: TokenExchangeInfo(newToken: Constants.dummyPushToken),
                                                    runCompletionIn: .main) { (optionalResult) in
                                                        defer {
                                                            expectation.fulfill()
                                                        }

                                                        guard let result = optionalResult else {
                                                            XCTFail()
                                                            return
                                                        }

                                                        guard case .success = result else {
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

    func testEnablePermissionSuccess() {
        // given
        NotificationEnablePermissionMock.register(mock: .success, notificationUnit: service.unit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.enablePermission(for: [Constants.dummyDid],
                                                      runCompletionIn: .main) { (optionalResult) in
                                                        defer {
                                                            expectation.fulfill()
                                                        }

                                                        guard let result = optionalResult else {
                                                            XCTFail()
                                                            return
                                                        }

                                                        guard case .success = result else {
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
