import Foundation

final class KYCUserDataModel {
    
    var name = ""
    var lastname = ""
    var phoneCountryCode = ""
    var phoneNumber = ""
    var email = ""
    var isEmailSent = false

    var lastPhoneOTPSentDate: Date?
    var lastEmailOTPSentDate = Date()
    var otpLength = 6

    var referenceId = ""
    var referenceNumber = ""
    var userId = ""
    var kycId = ""

    var haveEnoughXor = false

    var loginCase: LoginCase = .register

    var fullPhoneNumber: String {
        phoneCountryCode + phoneNumber
    }

    var secondsLeftForPhoneOTP: Int {
        if let lastPhoneOTPSentDate = lastPhoneOTPSentDate {
            return max(-Int(Date().timeIntervalSince(lastPhoneOTPSentDate + 60)), 0)
        } else {
            return 0
        }
    }

    enum LoginCase {
        case register
        case login
    }
}
