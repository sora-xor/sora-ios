/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore

class PhoneVerificationInteractorTests: NetworkBaseTests {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testFirstAttempSuccessfullVerification() {
        // given
        SmsCodeSendMock.register(mock: .successWithDelay, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        SmsCodeVerificationMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interactor = createInteractor()
        let presenter = PhoneVerificationPresenter()
        let wireframe = MockPhoneVerificationWireframeProtocol()
        let view = MockPhoneVerificationViewProtocol()

        let viewMatcher: ParameterMatcher<PhoneVerificationViewProtocol?> = ParameterMatcher { $0 === view }

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        SettingsManager.shared.removeValue(for: SettingsKey.verificationState.rawValue)

        let verificationCodeSentExpectation = XCTestExpectation()
        verificationCodeSentExpectation.assertForOverFulfill = false

        let verificationCompletedExpectation = XCTestExpectation()

        var startLoadingCalledTimes = 0
        var stopLoadingCalledTimes = 0

        stub(view) { stub in
            when(stub).didStartLoading().then {
                startLoadingCalledTimes += 1
            }

            when(stub).didStopLoading().then {
                stopLoadingCalledTimes += 1
            }

            when(stub).didReceive(viewModel: any(CodeInputViewModelProtocol.self)).thenDoNothing()
            when(stub).didUpdateResendRemained(delay: any(TimeInterval.self)).then { _ in
                verificationCodeSentExpectation.fulfill()
            }
        }

        stub(wireframe) { stub in
            when(stub).showAccessBackup(from: viewMatcher).then { _ in
                verificationCompletedExpectation.fulfill()
            }
        }

        // when

        XCTAssertNil(interactor.settings.value(of: VerificationState.self, for: SettingsKey.verificationState.rawValue))

        presenter.viewIsReady()

        wait(for: [verificationCodeSentExpectation], timeout: Constants.expectationDuration)

        let viewModel = CodeInputViewModel(length: 4, invalidCharacters: CharacterSet.decimalDigits.inverted)
        let enteringSuccess = viewModel.didReceiveReplacement(Constants.dummySmsCode,
                                                              for: NSRange(location: 0, length: 0))

        XCTAssertTrue(enteringSuccess)

        presenter.process(viewModel: viewModel)

        wait(for: [verificationCompletedExpectation], timeout: Constants.expectationDuration)


        // then

        XCTAssertNil(interactor.settings.verificationState)

        verify(view, times(1)).didReceive(viewModel: any(CodeInputViewModelProtocol.self))
        verify(view, atLeastOnce()).didUpdateResendRemained(delay: any(TimeInterval.self))

        XCTAssertEqual(startLoadingCalledTimes, stopLoadingCalledTimes)
    }

    // MARK: Private

    private func createInteractor() -> PhoneVerificationInteractor {
        let requestSigner = createDummyRequestSigner()

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = requestSigner

        return PhoneVerificationInteractor(projectService: projectService,
                                           settings: SettingsManager.shared)
    }
}
