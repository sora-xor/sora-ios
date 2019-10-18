import Foundation

extension PersonalForm {
    static func create(from country: Country) -> PersonalForm {
        return PersonalForm(firstName: "",
                            lastName: "",
                            countryCode: country.identitfier,
                            invitationCode: nil)
    }
}
