import Foundation

extension RegistrationInfo {
    static func create(with form: PersonalForm) -> RegistrationInfo {
        let userInfo = RegistrationUserInfo(firstName: form.firstName,
                                            lastName: form.lastName,
                                            country: form.countryCode)
        return RegistrationInfo(userData: userInfo,
                                invitationCode: form.invitationCode)
    }
}
