import Foundation
import PayWingsOAuthSDK

final class KYCEnterEmailCodeViewModel {
    var onContinue: ((KYCUserDataModel) -> Void)?
    var onChangeEmail: (() -> Void)?

    init(data: KYCUserDataModel, service: KYCService) {
        self.data = data
        self.service = service
        self.checkEmailCallback.delegate = self
        self.sendNewVerificationEmailCallback.delegate = self
    }

    let data: KYCUserDataModel
    private let service: KYCService
    private var codeState: KYCPhoneCodeState = .editing
    private var checkEmailCallback = CheckEmailVerifiedCallback()
    private var sendNewVerificationEmailCallback = SendNewVerificationEmailCallback()
    private var timer = Timer()

    func checkEmail() {

        timer.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(requestCheckEmailVerified),
            userInfo: nil,
            repeats: true
        )
    }

    func resendVerificationLink() {
        data.lastEmailOTPSentDate = .init()
        service.sendNewVerificationEmail(callback: sendNewVerificationEmailCallback)
    }

    @objc private func requestCheckEmailVerified() {
        service.checkEmailVerified(callback: checkEmailCallback)
    }
}

extension KYCEnterEmailCodeViewModel: CheckEmailVerifiedCallbackDelegate {
    func onSignInSuccessful() {
        timer.invalidate()
        onContinue?(self.data)
    }

    func onEmailNotVerified() {
        print("SCKYCEnterEmailCodeViewModel onEmailNotVerified")
    }
}

extension KYCEnterEmailCodeViewModel: SendNewVerificationEmailCallbackDelegate {

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        print("SCKYCEnterEmailCodeViewModel error:\(error)")
    }

    func onUserSignInRequired() {
        print("SCKYCEnterEmailCodeViewModel onUserSignInRequired")
    }
    
    func onShowEmailConfirmationScreen(email: String, autoEmailSent: Bool) {
        print("SCKYCEnterEmailCodeViewModel onShowEmailConfirmationScreen")
    }
}
