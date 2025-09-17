import PayWingsOAuthSDK

extension KYCService {

    struct UserDataResponse {
        let userId: String?
        let firstName: String?
        let lastName: String?
        let email: String?
        let emailConfirmed: Bool?
        let phoneNumber: String?
        let error: PayWingsOAuthSDK.OAuthErrorCode?
        let errorMessage: String?
    }

    func getUserData() async -> UserDataResponse {

        let callback = PayWingsOAuthSDK.GetUserDataCallback()
        callback.delegate = self


        return await withCheckedContinuation { continuation in
            getUserDataContinuation = continuation
            getUserData(callback: callback)
        }
    }

    func getUserData(callback: GetUserDataCallback) {
        Task {
            payWingsOAuthClient.getUserData(callback: callback)
        }
    }
}

extension KYCService: PayWingsOAuthSDK.GetUserDataCallbackDelegate {
    public func onUserData(
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        emailConfirmed: Bool,
        phoneNumber: String?
    ) {
        let data = UserDataResponse(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            email: email,
            emailConfirmed: emailConfirmed,
            phoneNumber: phoneNumber,
            error: nil,
            errorMessage: nil
        )
        getUserDataContinuation?.resume(returning: data)
    }

    public func onUserSignInRequired() {
        let data = UserDataResponse(
            userId: nil,
            firstName: nil,
            lastName: nil,
            email: nil,
            emailConfirmed: nil,
            phoneNumber: nil,
            error: nil,
            errorMessage: "User SignIn Required"
        )
        getUserDataContinuation?.resume(returning: data)
    }

    public func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        let data = UserDataResponse(
            userId: nil,
            firstName: nil,
            lastName: nil,
            email: nil,
            emailConfirmed: nil,
            phoneNumber: nil,
            error: error,
            errorMessage: errorMessage
        )
        getUserDataContinuation?.resume(returning: data)
    }
}
