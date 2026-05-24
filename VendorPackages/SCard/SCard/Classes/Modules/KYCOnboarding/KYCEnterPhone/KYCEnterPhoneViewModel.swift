import PayWingsOAuthSDK

final class KYCEnterPhoneViewModel {

    /// "^[\\+]?[(]?[0-9]{3}[)]?[-\\s.]?[0-9]{3}[-\\s.]?[0-9]{3,9}$"
    static let phoneNumberRegex = "^[\\+][0-9]{8,16}$"
    var onCountry: (() -> Void)?
    var onContinue: (() -> Void)?
    var onUpdateUI: ((String, Bool, Int) -> Void)?
    var onPhoneNumber: ((String) -> Void)?
    var onUpdateCountry: ((SCCountry) -> Void)?

    let data: KYCUserDataModel

    private let service: KYCService
    private var selectedCountry: SCCountry = .usa
    private let callback = SignInWithPhoneNumberRequestOtpCallback()
    private var dialCode = ""
    private var phoneNumber = ""

    private var isPhoneNumberZeroPrefixCorrectionOn: Bool {
        data.loginCase == .register
    }

    init(service: KYCService, data: KYCUserDataModel) {
        self.service = service
        self.data = data
        callback.delegate = self
    }

    func setupCrrentCountry() {
        Task {
            let response = await service.updateCountries()
            switch response {
            case .success(let countries):
                let regionCode = Locale.current.regionCode
                let country = countries
                    .first(where: { $0.code.lowercased() == regionCode?.lowercased() }) ?? .usa
                selectedCountry = country
                data.phoneCountryCode = country.dialCode
                await MainActor.run {
                    onUpdateCountry?(country)
                }
            case .failure(let error):
                print(error)
            }
        }
    }

    func onInput(text: String) {

        var cleanText = text
        if cleanText.first == "0" {
            if isPhoneNumberZeroPrefixCorrectionOn {
                cleanText = String(cleanText.drop(while: { $0 == "0"} ))
                onPhoneNumber?(cleanText)
            }
        }

        dialCode = selectedCountry.dialCode
        phoneNumber = cleanText
        let phone = dialCode + phoneNumber
        
        if cleanText.isEmpty {
            onUpdateUI?(
                R.string.soraCard.commonNoSpam(preferredLanguages: .currentLocale),
                false,
                data.secondsLeftForPhoneOTP
            )
        } else {
            if phone ~= Self.phoneNumberRegex {
                if phoneNumber.first == "0" {
                    onUpdateUI?("The phone number format entered seems unusual. If issues arise, consider removing the leading \"0\".", data.secondsLeftForPhoneOTP == 0, data.secondsLeftForPhoneOTP)
                } else {
                    onUpdateUI?("", data.secondsLeftForPhoneOTP == 0, data.secondsLeftForPhoneOTP)
                }
            } else {
                if phone.count > 7 {
                    onUpdateUI?("Wrong phone number format!", false, data.secondsLeftForPhoneOTP)
                }
            }
        }
    }

    func onCountrySelected(_ selectedCountry: SCCountry) {
        self.selectedCountry = selectedCountry
        data.phoneCountryCode = selectedCountry.dialCode
        onUpdateCountry?(selectedCountry)
    }

    func signIn() {
        data.phoneNumber = phoneNumber

        if data.secondsLeftForPhoneOTP == 0 {
            data.lastPhoneOTPSentDate = Date()
            onUpdateUI?("", false, data.secondsLeftForPhoneOTP)
            service.signInWithPhoneNumberRequestOtp(
                countryCode: dialCode,
                phoneNumber: phoneNumber,
                callback: callback
            )
        } else {
            onUpdateUI?("", false, data.secondsLeftForPhoneOTP)
            onContinue?()
        }
    }
}

extension KYCEnterPhoneViewModel: SignInWithPhoneNumberRequestOtpCallbackDelegate {
    func onShowTimeBasedOtpVerificationInputScreen(accountName: String) {
        print("TODO: onShowTimeBasedOtpVerificationInputScreen")
    }
    
    func onShowOtpInputScreen(otpLength: Int) {
        data.otpLength = otpLength
        onContinue?()
        onUpdateUI?("", false, data.secondsLeftForPhoneOTP) // todo stop timer
    }

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        onUpdateUI?(error.description, false, data.secondsLeftForPhoneOTP)
    }
}

extension String {
    static func ~= (lhs: String, rhs: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: rhs) else { return false }
        let range = NSRange(location: 0, length: lhs.utf16.count)
        return regex.firstMatch(in: lhs, options: [], range: range) != nil
    }
}
