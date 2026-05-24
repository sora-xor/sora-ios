import Foundation
import PayWingsOAuthSDK

enum SCEndpoint: Endpoint {
    case getReferenceNumber
    case kycLastStatus
    case kycAttemptCount
    case xOneStatus(paymentId: String)
    case price(pair: String)
    case xOneWidget
    case ibans
    case fees
    case version
    case countryCodes
    case onboardUser
    case onboarded
    case userIframe

    var path: String {
        switch self {
        case .getReferenceNumber:
            return "get-reference-number"
         case .kycLastStatus:
            return "kyc-last-status"
        case .kycAttemptCount:
            return "kyc-attempt-count"
        case .xOneStatus(let paymentId):
            return "x1-payment-status/\(paymentId)"
        case .price(let pair):
            return "prices/\(pair)"
        case .xOneWidget:
            return "widgets/sdk.js"
        case .ibans:
            return "ibans"
        case .fees:
            return "fees"
        case .version:
            return "version"
        case .countryCodes:
            return "country-codes"
        case .onboardUser:
            return "cryptogateway/onboard-user"
        case .onboarded:
            return "cryptogateway/onboarded"
        case .userIframe:
            return "cryptogateway/get-user-iframe"
        }
    }
}

public final class KYCService {

    let config: SCard.Config
    internal let client: APIClient
    internal var currentUserState: UserState = .none
    internal var currentUserIban: Iban?
    internal var retryFeeCache: String = "3.80"
    internal var applicationFeeCache: String = "29"
    internal var countries: [SCCountry] = []
    private var isRefreshAccessTokenInProgress = false
    private var kycStatusRefresherTimer: Timer?
    private let authCallback = OAuthInitializationCallback()
    internal var getUserDataContinuation: CheckedContinuation<UserDataResponse, Never>?

    internal lazy var payWingsOAuthClient: PayWingsOAuthSDK.OAuthServiceProtocol = {
        PayWingsOAuthClient.initialize(
            environmentType: config.environmentType.pwType,
            apiKey: config.pwApiKey,
            domain: config.pwAuthDomain,
            appPlatformID: config.appPlatformId,
            recaptchaKey: config.recaptchaKey,
            callback: authCallback
        )
        print("PayWingsOAuthClient isReady: \(PayWingsOAuthClient.isReady)")
        return PayWingsOAuthClient.instance()!
    }()

    init(client: APIClient, config: SCard.Config) {
        self.client = client
        self.config = config
        self.authCallback.delegate = self
        _ = payWingsOAuthClient
    }

    internal var _userStatusStream = SCStream(wrappedValue: KYCUserStatus.notStarted)

    func startKYCStatusRefresher() {
        guard kycStatusRefresherTimer == nil else { return }
        kycStatusRefresherTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard self?.isUserSignIn() ?? false else { return }
                _ = await self?.userStatus()
            }
        }
    }

    func isUserSignIn() -> Bool {
        payWingsOAuthClient.isUserSignIn()
    }

    func logout() {
        signOutUser()
        clearUserKYCState()
        clearIban()
    }

    private func signOutUser() {
        payWingsOAuthClient.signOutUser()
    }

    private func clearUserKYCState() {
        currentUserState = .none
        _userStatusStream.wrappedValue = .notStarted
    }

    private func clearIban() {
        Task {
            await IbanStorage.shared.ibansStream.finishAll()
            await IbanStorage.shared.set(ibans: .inited)
        }
    }

    func sendNewVerificationEmail(callback: SendNewVerificationEmailCallback) {
        payWingsOAuthClient.sendNewVerificationEmail(callback: callback)
    }

    func registerUser(data: KYCUserDataModel, callback: RegisterUserCallback) {
        payWingsOAuthClient.registerUser(
            firstName: data.name,
            lastName: data.lastname,
            email: data.email,
            callback: callback
        )
    }

    func changeUnverifiedEmail(email: String, callback: ChangeUnverifiedEmailCallback) {
        payWingsOAuthClient.changeUnverifiedEmail(email: email, callback: callback)
    }

    func signInWithPhoneNumberVerifyOtp(code: String, callback: SignInWithPhoneNumberVerifyOtpCallback) {
        payWingsOAuthClient.signInWithPhoneNumberVerifyOtp(otp: code, callback: callback)
    }

    func signInWithPhoneNumberRequestOtp(
        countryCode: String,
        phoneNumber: String,
        callback: SignInWithPhoneNumberRequestOtpCallback
    ) {
        payWingsOAuthClient.signInWithPhoneNumberRequestOtp(
            phoneNumberCountryCode: countryCode,
            phoneNumber: phoneNumber,
            smsContentTemplate: nil,
            callback: callback
        )
    }

    func checkEmailVerified(callback: CheckEmailVerifiedCallback) {
        payWingsOAuthClient.checkEmailVerified(callback: callback)
    }
}

extension KYCService: OAuthInitializationCallbackDelegate {
    public func onSuccess() {
        print("OAuthInitializationCallbackDelegate onSuccess")
    }
    
    public func onFailure(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        print("OAuthInitializationCallbackDelegate error:\(error) errorMessage:\(String(describing: errorMessage))")
    }
}
