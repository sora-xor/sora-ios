import Foundation
import SoraFoundation

final class PhoneVerificationPresenter {
    private struct Constants {
        static let defaultResendDelay = 60
        static let maxCodeLength = 4
    }

	weak var view: PhoneVerificationViewProtocol?
	var interactor: PhoneVerificationInteractorInputProtocol!
	var wireframe: PhoneVerificationWireframeProtocol!

    var logger: LoggerProtocol?

    let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }

    private(set) var verificationState: VerificationState?
    lazy private(set) var countdownTimer: CountdownTimer = {
        return CountdownTimer(delegate: self)
    }()

    private func provideNewViewModel() {
        let inputHandler = InputHandler(maxLength: PersonalInfoSharedConstants.phoneCodeLength,
                                        validCharacterSet: CharacterSet.decimalDigits,
                                        predicate: NSPredicate.phoneCode)

        let viewModel = InputViewModel(inputHandler: inputHandler)

        view?.didReceive(viewModel: viewModel)
    }

    private func updateVerificationState(with resendDelay: TimeInterval) {
        guard var verificationState = verificationState else {
            return
        }

        verificationState.didPerformAttempt(with: resendDelay)
        self.verificationState = verificationState

        interactor.save(verificationState: verificationState)

        updateResendCodeDisplayState()
    }

    private func updateResendCodeDisplayState() {
        guard let verificationState = verificationState else {
            return
        }

        if verificationState.canResendVerificationCode {
            view?.didUpdateResendRemained(delay: 0.0)
        } else {
            countdownTimer.start(with: verificationState.resendDelay)
        }
    }
}

extension PhoneVerificationPresenter: PhoneVerificationPresenterProtocol {
    func setup() {
        provideNewViewModel()

        view?.didStartLoading()

        interactor.fetchVerificationState()
    }

    func viewDidDisappear() {
        countdownTimer.stop()
    }

    func process(viewModel: InputViewModelProtocol) {
        view?.didStartLoading()

        let codeInfo = VerificationCodeInfo(code: viewModel.inputHandler.normalizedValue)
        interactor.verifyPhone(codeInfo: codeInfo)
    }

    func resendCode() {
        guard let verificationState = verificationState else {
            logger?.warning("Trying to resend code but verification state is unknown")
            return
        }

        let remainedDelay = verificationState.remainedDelay
        if remainedDelay > 0.0 {
            countdownTimer.start(with: remainedDelay)
            return
        }

        view?.didStartLoading()

        interactor.requestPhoneVerificationCode()
    }
}

extension PhoneVerificationPresenter: PhoneVerificationInteractorOutputProtocol {
    func didReceive(verificationCodeData: VerificationCodeData) {
        view?.didStopLoading()

        if verificationCodeData.status.isSuccess {
            let resendDelay = verificationCodeData.delay ?? Constants.defaultResendDelay
            updateVerificationState(with: TimeInterval(resendDelay))
        } else if let verificationRequestError = SmsCodeSendDataError.error(from: verificationCodeData.status) {
            if case .tooFrequentRequest = verificationRequestError {
                let resendDelay = verificationCodeData.delay ?? Constants.defaultResendDelay
                updateVerificationState(with: TimeInterval(resendDelay))

                wireframe.present(message: R.string.localizable
                    .phoneVerificationTooFrequentMessage(preferredLanguages: locale.rLanguages),
                                  title: R.string.localizable
                                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: locale.rLanguages),
                                  from: view)
            } else {
                handleSendVerificationCode(error: verificationRequestError)
                updateResendCodeDisplayState()
            }
        } else {
            logger?.error("Unexpected phone verification status \(verificationCodeData.status.code)")
            updateResendCodeDisplayState()
        }
    }

    func didReceivePhoneVerificationCodeRequest(error: Error) {
        view?.didStopLoading()

        updateResendCodeDisplayState()

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }

        if let verificationRequestError = error as? SmsCodeSendDataError {
            handleSendVerificationCode(error: verificationRequestError)
        } else {
            logger?.error("Unexpected phone verification request error received \(error)")
        }
    }

    private func handleSendVerificationCode(error: SmsCodeSendDataError) {
        switch error {
        case .userNotFound, .userValuesNotFound:
            wireframe.present(message: R.string.localizable
                .phoneVerificationUserNotFoundMessage(preferredLanguages: locale.rLanguages),
                              title: R.string.localizable
                                .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                              closeAction: R.string.localizable
                                .commonClose(preferredLanguages: locale.rLanguages),
                              from: view)
        case .tooFrequentRequest:
            wireframe.present(message: R.string.localizable
                .phoneVerificationTooFrequentMessage(preferredLanguages: locale.rLanguages),
                              title: R.string.localizable
                                .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                              closeAction: R.string.localizable
                                .commonClose(preferredLanguages: locale.rLanguages),
                              from: view)
        }
    }

    func didVerifyPhoneCode() {
        view?.didStopLoading()

        wireframe.showNext(from: view)
    }

    func didReceivePhoneVerification(error: Error) {
        view?.didStopLoading()

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }

        if let verificationError = error as? SmsCodeVerifyDataError {
            switch verificationError {
            case .userNotFound:
                wireframe.present(message: R.string.localizable
                    .phoneVerificationUserNotFoundMessage(preferredLanguages: locale.rLanguages),
                                  title: R.string.localizable
                                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: locale.rLanguages),
                                  from: view)
            case .smsCodeExpired:
                wireframe.present(message: R.string.localizable
                    .phoneVerificationCodeExpiredMessage(preferredLanguages: locale.rLanguages),
                                  title: R.string.localizable
                                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: locale.rLanguages),
                                  from: view)
            case .smsCodeIncorrect:
                wireframe.present(message: R.string.localizable
                    .phoneVerificationCodeIncorrectMessage(preferredLanguages: locale.rLanguages),
                                  title: R.string.localizable
                                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: locale.rLanguages),
                                  from: view)

                provideNewViewModel()
            case .smsCodeNotFound:
                wireframe.present(message: R.string.localizable
                    .phoneVerificationCodeNotFoundMessage(preferredLanguages: locale.rLanguages),
                                  title: R.string.localizable
                                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: locale.rLanguages),
                                  from: view)
            }
        } else {
            logger?.error("Unexpected phone verification error received \(error)")
        }
    }

    func didReceive(verificationState: VerificationState?) {
        view?.didStopLoading()

        if let currentVerificationState = verificationState {
            self.verificationState = currentVerificationState
        } else {
            let currentVerificationState = VerificationState()
            self.verificationState = currentVerificationState

            interactor.save(verificationState: currentVerificationState)
        }

        resendCode()
    }
}

extension PhoneVerificationPresenter: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        view?.didUpdateResendRemained(delay: interval)
    }

    func didCountdown(remainedInterval: TimeInterval) {
        view?.didUpdateResendRemained(delay: remainedInterval)
    }

    func didStop(with remainedInterval: TimeInterval) {
        view?.didUpdateResendRemained(delay: 0.0)
    }
}
