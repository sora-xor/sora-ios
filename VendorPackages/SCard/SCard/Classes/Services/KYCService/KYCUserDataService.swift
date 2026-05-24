import PayWingsOAuthSDK

final class KYCUserDataService {

    private let service: KYCService
    private var data: KYCUserDataModel?
    private let getUserDataCallback = GetUserDataCallback()
    private var continuation: CheckedContinuation<KYCUserDataModel?, Never>?

    init(service: KYCService) {
        self.service = service
        getUserDataCallback.delegate = self
    }

    func fetchUserData() async -> KYCUserDataModel? {
        self.service.getUserData(callback: getUserDataCallback)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

extension KYCUserDataService: GetUserDataCallbackDelegate {
    func onUserSignInRequired() {
        print("SCKYCUserDataService onUserSignInRequired")
        continuation?.resume(returning: nil)
    }
    
    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        print("SCKYCUserDataService onError \(error) \(errorMessage ?? "")")
        continuation?.resume(returning: nil)
    }

    func onUserData(
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        emailConfirmed: Bool,
        phoneNumber: String?
    ) {
        let data = KYCUserDataModel()
        data.userId = userId
        data.name = firstName ?? ""
        data.lastname = lastName ?? ""
        data.phoneNumber = phoneNumber ?? ""
        data.email = email ?? ""
        data.isEmailSent = !(email ?? "").isEmpty
        continuation?.resume(returning: data)
    }
}
