/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol PersonalInfoViewModelFactoryProtocol {
    func createRegistrationForm(from form: PersonalForm, locale: Locale) -> [PersonalInfoViewModel]
    func createViewModels(from user: UserData?, locale: Locale) -> [PersonalInfoViewModel]
}

final class PersonalInfoViewModelFactory {

    private func applyNameFilter(for value: String) -> String {
        if value.count > PersonalInfoSharedConstants.personNameLimit {
            return ""
        }

        if value.rangeOfCharacter(from: CharacterSet.personName.inverted) != nil {
            return ""
        }

        return value
    }

    private func createFirstNameViewModel(with value: String, locale: Locale) -> PersonalInfoViewModel {
        let title = R.string.localizable.personalInfoFirstName(preferredLanguages: locale.rLanguages)
        return PersonalInfoViewModel(title: title,
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.personNameLimit,
                                     validCharacterSet: CharacterSet.personName,
                                     predicate: NSPredicate.notEmpty,
                                     autocapitalizationType: .words)
    }

    private func createLastNameViewModel(with value: String, locale: Locale) -> PersonalInfoViewModel {
        let title = R.string.localizable.personalInfoLastName(preferredLanguages: locale.rLanguages)
        return PersonalInfoViewModel(title: title,
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.personNameLimit,
                                     validCharacterSet: CharacterSet.personName,
                                     predicate: NSPredicate.notEmpty,
                                     autocapitalizationType: .words)
    }

    private func createPhoneViewModel(with value: String, locale: Locale) -> PersonalInfoViewModel {
        let title = R.string.localizable.personalInfoPhone(preferredLanguages: locale.rLanguages)
        return PersonalInfoViewModel(title: title,
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.phoneLimit,
                                     validCharacterSet: CharacterSet.phone,
                                     predicate: NSPredicate.phone,
                                     autocapitalizationType: .none)
    }

    private func createInvitationCodeViewModel(with value: String, locale: Locale) -> PersonalInfoViewModel {
        let predicates = [NSPredicate.invitationCode, NSPredicate.empty]
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        let title = R.string.localizable.personalInfoInvCodeHint(preferredLanguages: locale.rLanguages)
        return PersonalInfoViewModel(title: title,
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.invitationCodeLimit,
                                     validCharacterSet: CharacterSet.alphanumerics,
                                     predicate: compoundPredicate,
                                     autocapitalizationType: .none)
    }
}

extension PersonalInfoViewModelFactory: PersonalInfoViewModelFactoryProtocol {
    func createRegistrationForm(from form: PersonalForm, locale: Locale) -> [PersonalInfoViewModel] {
        let firstNameModel = createFirstNameViewModel(with: applyNameFilter(for: form.firstName),
                                                      locale: locale)
        let lastNameModel = createLastNameViewModel(with: applyNameFilter(for: form.lastName),
                                                    locale: locale)
        let invitationCode = createInvitationCodeViewModel(with: form.invitationCode ?? "",
                                                           locale: locale)

        return [firstNameModel, lastNameModel, invitationCode]
    }

    func createViewModels(from user: UserData?, locale: Locale) -> [PersonalInfoViewModel] {
        let firstNameModel = createFirstNameViewModel(with: user?.firstName ?? "", locale: locale)
        let lastNameModel = createLastNameViewModel(with: user?.lastName ?? "", locale: locale)
        let phoneModel = createPhoneViewModel(with: user?.phone ?? "", locale: locale)

        return [firstNameModel, lastNameModel, phoneModel]
    }
}
