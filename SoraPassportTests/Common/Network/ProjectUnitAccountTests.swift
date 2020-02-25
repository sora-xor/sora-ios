/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import RobinHood

class ProjectUnitAccountServiceTests: NetworkBaseTests {
    var service: ProjectUnitService!

    override func setUp() {
        super.setUp()

        service = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        service.requestSigner = createDummyRequestSigner()
    }

    func testCustomerFetchSuccess() {
        // given
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

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

    func testUserCreationSuccess() {
        // given
        UserCreationMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let userCreationInfo = UserCreationInfo(phone: Constants.dummyPhone)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.createCustomer(with: userCreationInfo, runCompletionIn: .main) { optionalResult in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success(let verificationData) = result else {
                XCTFail()
                return
            }

            XCTAssertTrue(verificationData.status.isSuccess)
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testUserCreationAlreadyExists() {
        performUserCreationErrorTest(with: .alreadyRegistered, expectedError: UserCreationError.alreadyExists)
    }

    func testUserCreationVerify() {
        performUserCreationErrorTest(with: .alreadyVerified, expectedError: UserCreationError.verified)
    }

    func testRegistrationSuccess() {
        // given
        ProjectsRegisterMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        var form = PersonalForm.create(from: createRandomCountry())
        form.firstName = Constants.dummyFirstName
        form.lastName = Constants.dummyLastName
        form.invitationCode = Constants.dummyInvitationCode

        let registrationInfo = RegistrationInfo.create(with: form)

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

    func testApplyInvitationSuccess() {
        // given

        ApplyInvitationMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when

        let operation = try? service.applyInvitation(code: Constants.dummyInvitationCode,
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

    func testCheckInvitationSuccess() {
        CheckInvitationMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        performCheckInvitationTest { result in
            if let result = result, case .success = result {
                return true
            } else {
                return false
            }
        }
    }

    func testCheckInvitationNotFound() {
        CheckInvitationMock.register(mock: .notFound, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        performCheckInvitationTest { result in
            if let result = result,
                case .failure(let error) = result,
                let checkInvitationError = error as? InvitationCheckDataError {

                return checkInvitationError == .notFound
            } else {
                return false
            }
        }
    }

    func testCheckInvitationAmbigious() {
        CheckInvitationMock.register(mock: .ambigious, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        performCheckInvitationTest { result in
            if let result = result,
                case .failure(let error) = result,
                let checkInvitationError = error as? InvitationCheckDataError {

                return checkInvitationError == .ambigious
            } else {
                return false
            }

        }
    }

    private func performCheckInvitationTest(for closure:
        @escaping (Result<InvitationCheckData, Error>?) -> Bool) {

        let expectation = XCTestExpectation()

        do {

            let deviceInfo = DeviceInfoFactory().createDeviceInfo()

            _ = try service.checkInvitation(for: deviceInfo, runCompletionIn: .main) { (result) in
                XCTAssert(closure(result))

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        } catch {
            XCTFail("Unexpected error \(error)")
        }
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
        let codeInfo = VerificationCodeInfo(code: Constants.dummySmsCode)
        let operation = try? service.verifySms(codeInfo: codeInfo, runCompletionIn: .main) { (optionalResult) in
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

    // MARK: Private

    private func performUserCreationErrorTest(with mock: UserCreationMock, expectedError: UserCreationError) {
        // given
        UserCreationMock.register(mock: mock, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let userCreationInfo = UserCreationInfo(phone: Constants.dummyPhone)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.createCustomer(with: userCreationInfo, runCompletionIn: .main) { optionalResult in
            defer {
                expectation.fulfill()
            }

            guard
                let result = optionalResult,
                case .failure(let error) = result,
                let userCreationError = error as? UserCreationError,
                expectedError == userCreationError else {
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
