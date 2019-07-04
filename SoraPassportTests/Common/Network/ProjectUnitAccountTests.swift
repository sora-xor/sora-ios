/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport

class ProjectUnitAccountServiceTests: NetworkBaseTests {
    var service: ProjectUnitService!

    override func setUp() {
        super.setUp()

        service = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        service.requestSigner = createDummyRequestSigner()
    }

    func testCustomerFetchSuccess() {
        // given
        ProjectsCustomerMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchCustomer(runCompletionIn: .main) { (optionalResult) in
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

    func testCustomerUpdateSuccess() {
        // given
        UpdateCustomerMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        let personalInfo = PersonalInfo(firstName: Constants.dummyFirstName,
                                        lastName: Constants.dummyLastName,
                                        email: Constants.dummyEmail)

        // when
        let operation = try? service.updateCustomer(with: personalInfo, runCompletionIn: .main) { (optionalResult) in
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

    func testCheckInvitationSuccessWithForm() {
        // given
        ProjectsCheckInvitationMock.register(mock: .successWithForm, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.checkInvitation(code: Constants.dummyInvitationCode, runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success(let applicationForm) = result else {
                XCTFail()
                return
            }

            guard applicationForm != nil else {
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

    func testCheckInvitationSuccessEmptyForm() {
        // given
        ProjectsCheckInvitationMock.register(mock: .successEmpty, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.checkInvitation(code: Constants.dummyInvitationCode, runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success(let applicationForm) = result else {
                XCTFail()
                return
            }

            guard applicationForm == nil else {
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

    func testCheckInvitationSuccessNilForm() {
        // given
        ProjectsCheckInvitationMock.register(mock: .successNil, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.checkInvitation(code: Constants.dummyInvitationCode, runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success(let applicationForm) = result else {
                XCTFail()
                return
            }

            guard applicationForm == nil else {
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

    func testRegistrationSuccess() {
        // given
        ProjectsRegisterMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let applicationInfo = ApplicationFormInfo(applicationId: Constants.dummyApplicationFormId,
                                                  firstName: Constants.dummyFirstName,
                                                  lastName: Constants.dummyLastName,
                                                  phone: Constants.dummyPhone,
                                                  email: Constants.dummyEmail)
        let registrationInfo = RegistrationInfo(applicationForm: applicationInfo,
                                                invitationCode: Constants.dummyInvitationCode)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.registerCustomer(with: registrationInfo, runCompletionIn: .main) { (optionalResult) in
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

    func testInvitationFetchSuccess() {
        // given
        ProjectsFetchInvitationCodeMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchInvitationCode(runCompletionIn: .main) { (optionalResult) in
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

    func testMarkInvitationSuccess() {
        // given
        ProjectsMarkInvitationMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.markAsUsed(invitationCode: Constants.dummyInvitationCode,
                                                runCompletionIn: .main) { (optionalResult) in
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

    func testInvitedSuccess() {
        performInvitedTest(for: .successWithoutParent)
        performInvitedTest(for: .successWithParent)
    }

    private func performInvitedTest(for mock: ProjectsInvitedMock) {
        // given
        ProjectsInvitedMock.register(mock: mock, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchActivatedInvitations(runCompletionIn: .main) { (optionalResult) in
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

    func testReputationSuccess() {
        // given
        performTestReputationSuccess(for: .success)
        performTestReputationSuccess(for: .nullSuccess)
    }

    private func performTestReputationSuccess(for mock: ProjectsReputationFetchMock) {
        // given
        ProjectsReputationFetchMock.register(mock: mock, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchReputation(runCompletionIn: .main) { (optionalResult) in
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

    func testSmsCodeSendSuccess() {
        performTestSmsSend(with: .successEmpty, expected: nil)
        performTestSmsSend(with: .successWithDelay, expected: nil)
        performTestSmsSend(with: .tooFrequent, expected: SmsCodeSendDataError.tooFrequentRequest)
    }

    func performTestSmsSend(with mock: SmsCodeSendMock, expected error: SmsCodeSendDataError?) {
        // given
        SmsCodeSendMock.register(mock: mock, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.sendSmsCode(runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success(let verificationData) = result else {
                XCTFail()
                return
            }

            if let expectedError = error {
                let receivedError = SmsCodeSendDataError.error(from: verificationData.status)
                XCTAssertEqual(receivedError, expectedError)
            } else {
                XCTAssertTrue(verificationData.status.isSuccess)
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testSmsCodeVerificationSuccess() {
        // given
        SmsCodeVerificationMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.verifySms(code: Constants.dummySmsCode, runCompletionIn: .main) { (optionalResult) in
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

    func testAnnouncementNotEmptySuccess() {
        // given
        AnnouncementFetchMock.register(mock: .successNotEmpty, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

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

            XCTAssertNotNil(announcement)
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testActivityFetchSuccess() {
        // given
        ActivityFeedMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let pagination = Pagination(offset: 0, count: 50)
        let operation = try? service.fetchActivityFeed(with: pagination, runCompletionIn: .main) { (optionalResult) in
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
