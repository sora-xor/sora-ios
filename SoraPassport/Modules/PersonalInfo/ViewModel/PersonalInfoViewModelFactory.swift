/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol PersonalInfoViewModelFactoryProtocol {
    func createRegistrationForm(from form: PersonalForm) -> [PersonalInfoViewModel]
    func createViewModels(from user: UserData?) -> [PersonalInfoViewModel]
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

    private func createFirstNameViewModel(with value: String) -> PersonalInfoViewModel {
        return PersonalInfoViewModel(title: R.string.localizable.personalInfoFirstName(),
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.personNameLimit,
                                     validCharacterSet: CharacterSet.personName,
                                     predicate: NSPredicate.notEmpty,
                                     autocapitalizationType: .words)
    }

    private func createLastNameViewModel(with value: String) -> PersonalInfoViewModel {
        return PersonalInfoViewModel(title: R.string.localizable.personalInfoLastName(),
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.personNameLimit,
                                     validCharacterSet: CharacterSet.personName,
                                     predicate: NSPredicate.notEmpty,
                                     autocapitalizationType: .words)
    }

    private func createPhoneViewModel(with value: String) -> PersonalInfoViewModel {
        return PersonalInfoViewModel(title: R.string.localizable.personalInfoPhone(),
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.phoneLimit,
                                     validCharacterSet: CharacterSet.phone,
                                     predicate: NSPredicate.phone,
                                     autocapitalizationType: .none)
    }

    private func createInvitationCodeViewModel(with value: String) -> PersonalInfoViewModel {
        let predicates = [NSPredicate.invitationCode, NSPredicate.empty]
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return PersonalInfoCodeViewModel(title: R.string.localizable.personalInfoInvitationCode(),
                                         value: value,
                                         maxLength: PersonalInfoSharedConstants.invitationCodeLimit,
                                         validCharacterSet: CharacterSet.alphanumerics,
                                         predicate: compoundPredicate,
                                         autocapitalizationType: .none)
    }
}

extension PersonalInfoViewModelFactory: PersonalInfoViewModelFactoryProtocol {
    func createRegistrationForm(from form: PersonalForm) -> [PersonalInfoViewModel] {
        let firstNameModel = createFirstNameViewModel(with: applyNameFilter(for: form.firstName))
        let lastNameModel = createLastNameViewModel(with: applyNameFilter(for: form.lastName))
        let invitationCode = createInvitationCodeViewModel(with: form.invitationCode ?? "")

        return [firstNameModel, lastNameModel, invitationCode]
    }

    func createViewModels(from user: UserData?) -> [PersonalInfoViewModel] {
        let firstNameModel = createFirstNameViewModel(with: user?.firstName ?? "")
        let lastNameModel = createLastNameViewModel(with: user?.lastName ?? "")
        let phoneModel = createPhoneViewModel(with: user?.phone ?? "")

        return [firstNameModel, lastNameModel, phoneModel]
    }
}
