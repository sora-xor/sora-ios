import Foundation
import PayWingsOAuthSDK

enum KYCPhoneCodeState {
    case editing
    case sent
    case wrong(String)
    case succeed
}

final class KYCEnterPhoneCodeViewModel {

    static let phoneCodeRegex = "[0-9]{4,6}$"

    var onEmailVerification: ((KYCUserDataModel) -> Void)?
    var onUserRegistration: ((KYCUserDataModel) -> Void)?
    var onUserNotRegistred: ((KYCUserDataModel) -> Void)?
    var onSignInSuccessfully: ((KYCUserDataModel) -> Void)?

    var onResend: ((KYCUserDataModel) -> Void)?
    var onUpdateUI: (() -> Void)?

    var getUserDataCallback = GetUserDataCallback()

    init(data: KYCUserDataModel, service: KYCService) {
        self.data = data
        self.service = service
        getUserDataCallback.delegate = self
    }

    let data: KYCUserDataModel
    var codeState: KYCPhoneCodeState = .editing

    private let service: KYCService

    func check(code: String) {
        if code.count < data.otpLength {
            codeState = .editing
            onUpdateUI?()
            return
        }

        if code ~= Self.phoneCodeRegex {
            codeState = .sent
            onUpdateUI?()
            let callback = SignInWithPhoneNumberVerifyOtpCallback()
            callback.delegate = self
            service.signInWithPhoneNumberVerifyOtp(code: code, callback: callback)
            return
        }

        codeState = .wrong("Wrong format!") // TODO: localize
        onUpdateUI?()
    }
}

extension KYCEnterPhoneCodeViewModel: SignInWithPhoneNumberVerifyOtpCallbackDelegate {
    func onSignInSuccessful() {
        Task { [weak self] in
            guard let self = self else { return }
            self.service.getUserData(callback: self.getUserDataCallback)
            await MainActor.run {
                self.onUpdateUI?()
            }
        }
    }
    
    func onShowTimeBasedOtpVerificationInputScreen(accountName: String) {
        print("TODO: onShowTimeBasedOtpVerificationInputScreen")
    }
    
    func onShowTimeBasedOtpSetupScreen(accountName: String, secretKey: String) {
        print("TODO: onShowTimeBasedOtpSetupScreen")
    }
    
    func onShowEmailConfirmationScreen(email: String, autoEmailSent: Bool) {
        data.email = email
        data.isEmailSent = true
        codeState = .succeed
        onEmailVerification?(data)
    }

    func onShowRegistrationScreen() {
        codeState = .succeed
        onUpdateUI?()

        if data.loginCase == .register {
            onUserRegistration?(data)
        } else {
            onUserNotRegistred?(data)
        }
    }

    func onUserSignInRequired() {
        print("TODO: onUserSignInRequired")
    }

    func onVerificationFailed() {
        codeState = .wrong(R.string.soraCard.otpErrorMessageWrongCode(preferredLanguages: .currentLocale))
        onUpdateUI?()
    }

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        codeState = .wrong(errorMessage ?? error.description)
        onUpdateUI?()
    }
}

extension KYCEnterPhoneCodeViewModel: GetUserDataCallbackDelegate {

    func onUserData(
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        emailConfirmed: Bool,
        phoneNumber: String?
    ) {
        data.userId = userId
        data.name = firstName ?? ""
        data.lastname = lastName ?? ""
        data.email = email ?? ""

        onSignInSuccessfully?(data)
    }
}
