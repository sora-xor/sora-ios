/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol PersonalInfoViewModelFactoryProtocol {
    func createEmpty() -> [PersonalInfoViewModel]
    func createViewModels(from applicationForm: ApplicationFormData) -> [PersonalInfoViewModel]
    func createViewModels(from user: UserData) -> [PersonalInfoViewModel]
}

final class PersonalInfoViewModelFactory {
    private func createFirstNameViewModel(with value: String) -> PersonalInfoViewModel {
        return PersonalInfoViewModel(title: R.string.localizable.personalInfoFirstName(),
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.personNameLimit,
                                     validCharacterSet: CharacterSet.personName,
                                     predicate: NSPredicate.notEmpty)
    }

    private func createLastNameViewModel(with value: String) -> PersonalInfoViewModel {
        return PersonalInfoViewModel(title: R.string.localizable.personalInfoLastName(),
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.personNameLimit,
                                     validCharacterSet: CharacterSet.personName,
                                     predicate: NSPredicate.notEmpty)
    }

    private func createPhoneViewModel(with value: String) -> PersonalInfoViewModel {
        return PersonalInfoViewModel(title: R.string.localizable.personalInfoPhone(),
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.phoneLimit,
                                     validCharacterSet: CharacterSet.phone,
                                     predicate: NSPredicate.phone)
    }

    private func createEmailViewModel(with value: String) -> PersonalInfoViewModel {
        return PersonalInfoViewModel(title: R.string.localizable.personalInfoEmail(),
                                     value: value,
                                     maxLength: PersonalInfoSharedConstants.emailLimit,
                                     validCharacterSet: CharacterSet.email,
                                     predicate: NSPredicate.email)
    }
}

extension PersonalInfoViewModelFactory: PersonalInfoViewModelFactoryProtocol {
    func createEmpty() -> [PersonalInfoViewModel] {
        let firstNameModel = createFirstNameViewModel(with: "")
        let lastNameModel = createLastNameViewModel(with: "")
        let phoneModel = createPhoneViewModel(with: "")
        let emailModel = createEmailViewModel(with: "")

        return [firstNameModel, lastNameModel, phoneModel, emailModel]
    }

    func createViewModels(from user: UserData) -> [PersonalInfoViewModel] {
        let firstNameModel = createFirstNameViewModel(with: user.firstName)
        let lastNameModel = createLastNameViewModel(with: user.lastName)
        let phoneModel = createPhoneViewModel(with: user.phone ?? "")
        let emailModel = createEmailViewModel(with: user.email)

        return [firstNameModel, lastNameModel, phoneModel, emailModel]
    }

    func createViewModels(from applicationForm: ApplicationFormData) -> [PersonalInfoViewModel] {
        let firstNameModel = createFirstNameViewModel(with: applicationForm.firstName ?? "")
        let lastNameModel = createLastNameViewModel(with: applicationForm.lastName ?? "")
        let phoneModel = createPhoneViewModel(with: applicationForm.phone ?? "")
        let emailModel = createEmailViewModel(with: applicationForm.email ?? "")

        return [firstNameModel, lastNameModel, phoneModel, emailModel]
    }
}
