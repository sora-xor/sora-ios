/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore
import SoraFoundation

class PhoneVerificationInteractorTests: NetworkBaseTests {

    func testFirstAttempSuccessfullVerification() {
        // given
        SmsCodeSendMock.register(mock: .successWithDelay, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        SmsCodeVerificationMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let presenter = PhoneVerificationPresenter(locale: Locale.current)
        let wireframe = MockPhoneVerificationWireframeProtocol()
        let view = MockPhoneVerificationViewProtocol()

        var settings = InMemorySettingsManager()
        settings.decentralizedId = Constants.dummyDid
        settings.verificationState = VerificationState()

        // when

        performSetup(for: presenter, view: view, wireframe: wireframe, settings: settings)

        let viewMatcher: ParameterMatcher<PhoneVerificationViewProtocol?> = ParameterMatcher { $0 === view }

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
        }

        stub(wireframe) { stub in
            when(stub).showNext(from: viewMatcher).then { _ in
                verificationCompletedExpectation.fulfill()
            }
        }

        let viewModel = CodeInputViewModel(length: 4, invalidCharacters: CharacterSet.decimalDigits.inverted)
        let enteringSuccess = viewModel.didReceiveReplacement(Constants.dummySmsCode,
                                                              for: NSRange(location: 0, length: 0))

        XCTAssertTrue(enteringSuccess)

        presenter.process(viewModel: viewModel)

        wait(for: [verificationCompletedExpectation], timeout: Constants.expectationDuration)


        // then

        verify(view, times(1)).didReceive(viewModel: any(CodeInputViewModelProtocol.self))
        verify(view, atLeastOnce()).didUpdateResendRemained(delay: any(TimeInterval.self))

        XCTAssertEqual(startLoadingCalledTimes, stopLoadingCalledTimes)

        XCTAssertEqual(settings.decentralizedId, Constants.dummyDid)
        XCTAssertNotNil(settings.verificationState)
    }

    func testInvalidVerificationCode() {
        // given

        SmsCodeSendMock.register(mock: .successEmpty, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        SmsCodeVerificationMock.register(mock: .incorrect, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let presenter = PhoneVerificationPresenter(locale: Locale.current)
        let wireframe = MockPhoneVerificationWireframeProtocol()
        let view = MockPhoneVerificationViewProtocol()

        var settings = InMemorySettingsManager()
        settings.decentralizedId = Constants.dummyDid
        settings.verificationState = VerificationState()

        // when

        performSetup(for: presenter, view: view, wireframe: wireframe, settings: settings)

        let countdownTimerDelegate = MockCountdownTimerDelegate()
        presenter.countdownTimer.delegate = countdownTimerDelegate

        stub(countdownTimerDelegate) { stub in
            when(stub).didStart(with: any()).then { _ in
                XCTFail("Unexpected timer restart")
            }

            when(stub).didCountdown(remainedInterval: any()).thenDoNothing()
            when(stub).didStop(with: any()).thenDoNothing()
        }

        var startLoadingCalledTimes = 0
        var stopLoadingCalledTimes = 0

        stub(view) { stub in
            when(stub).didStartLoading().then {
                startLoadingCalledTimes += 1
            }

            when(stub).didStopLoading().then {
                stopLoadingCalledTimes += 1
            }

            when(stub).didUpdateResendRemained(delay: any()).thenDoNothing()
        }

        let errorExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(error: any(), from: any(), locale: any()).then { _ in
                errorExpectation.fulfill()
                return true
            }
        }

        let viewModel = CodeInputViewModel(length: 4, invalidCharacters: CharacterSet.decimalDigits.inverted)
        let enteringSuccess = viewModel.didReceiveReplacement(Constants.dummySmsCode,
                                                              for: NSRange(location: 0, length: 0))

        XCTAssertTrue(enteringSuccess)

        presenter.process(viewModel: viewModel)

        // then

        wait(for: [errorExpectation], timeout: Constants.expectationDuration)

        XCTAssertEqual(settings.decentralizedId, Constants.dummyDid)
        XCTAssertNotNil(settings.verificationState)
    }

    // MARK: Private

    private func performSetup(for presenter: PhoneVerificationPresenter,
                              view: MockPhoneVerificationViewProtocol,
                              wireframe: MockPhoneVerificationWireframeProtocol,
                              settings: SettingsManagerProtocol) {
        // given

        let interactor = createInteractor(with: settings)
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let verificationCodeSentExpectation = XCTestExpectation()
        verificationCodeSentExpectation.assertForOverFulfill = false

        stub(view) { stub in
            when(stub).didStartLoading().thenDoNothing()

            when(stub).didStopLoading().thenDoNothing()

            when(stub).didReceive(viewModel: any(CodeInputViewModelProtocol.self)).thenDoNothing()
            when(stub).didUpdateResendRemained(delay: any(TimeInterval.self)).then { _ in
                verificationCodeSentExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [verificationCodeSentExpectation], timeout: Constants.expectationDuration)
    }

    private func createInteractor(with settings: SettingsManagerProtocol) -> PhoneVerificationInteractor {
        let requestSigner = createDummyRequestSigner()

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = requestSigner

        return PhoneVerificationInteractor(projectService: projectService,
                                           settings: settings)
    }
}
