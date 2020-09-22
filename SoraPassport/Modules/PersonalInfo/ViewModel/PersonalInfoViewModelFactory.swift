/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

protocol PersonalInfoViewModelFactoryProtocol {
    func createRegistrationForm(from form: PersonalForm, locale: Locale) -> [InputViewModel]
    func createViewModels(from user: UserData?, locale: Locale) -> [InputViewModel]
}

final class PersonalInfoViewModelFactory {

    private func createFirstNameViewModel(with value: String, locale: Locale) -> InputViewModel {
        let title = R.string.localizable.personalInfoFirstName(preferredLanguages: locale.rLanguages)

        let inputHandler = InputHandler(value: value,
                                        maxLength: PersonalInfoSharedConstants.personNameLimit,
                                        validCharacterSet: CharacterSet.personName,
                                        predicate: NSPredicate.personName,
                                        processor: CompoundTextProcessor.personName,
                                        normalizer: TrimmingCharacterProcessor.personName)

        return InputViewModel(inputHandler: inputHandler, title: title, autocapitalization: .words)
    }

    private func createLastNameViewModel(with value: String, locale: Locale) -> InputViewModel {
        let title = R.string.localizable.personalInfoLastName(preferredLanguages: locale.rLanguages)

        let inputHandler = InputHandler(value: value,
                                        maxLength: PersonalInfoSharedConstants.personNameLimit,
                                        validCharacterSet: CharacterSet.personName,
                                        predicate: NSPredicate.personName,
                                        processor: CompoundTextProcessor.personName,
                                        normalizer: TrimmingCharacterProcessor.personName)

        return InputViewModel(inputHandler: inputHandler, title: title, autocapitalization: .words)
    }

    private func createPhoneViewModel(with value: String, enabled: Bool, locale: Locale) -> InputViewModel {
        let title = R.string.localizable.personalInfoPhone(preferredLanguages: locale.rLanguages)

        let inputHandler = InputHandler(value: value,
                                        enabled: enabled,
                                        maxLength: PersonalInfoSharedConstants.phoneLimit,
                                        validCharacterSet: CharacterSet.phone,
                                        predicate: NSPredicate.phone)

        return InputViewModel(inputHandler: inputHandler, title: title, autocapitalization: .none)
    }

    private func createInvitationCodeViewModel(with value: String, locale: Locale) -> InputViewModel {
        let predicates = [NSPredicate.invitationCode, NSPredicate.empty]
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        let title = R.string.localizable.personalInfoInvCodeHint(preferredLanguages: locale.rLanguages)

        let inputHandler = InputHandler(value: value,
                                        required: false,
                                        maxLength: PersonalInfoSharedConstants.invitationCodeLimit,
                                        validCharacterSet: CharacterSet.alphanumerics,
                                        predicate: compoundPredicate)

        return InputViewModel(inputHandler: inputHandler, title: title, autocapitalization: .none)
    }
}

extension PersonalInfoViewModelFactory: PersonalInfoViewModelFactoryProtocol {
    func createRegistrationForm(from form: PersonalForm, locale: Locale) -> [InputViewModel] {
        let firstNameModel = createFirstNameViewModel(with: form.firstName,
                                                      locale: locale)
        let lastNameModel = createLastNameViewModel(with: form.lastName,
                                                    locale: locale)
        let invitationCode = createInvitationCodeViewModel(with: form.invitationCode ?? "",
                                                           locale: locale)

        return [firstNameModel, lastNameModel, invitationCode]
    }

    func createViewModels(from user: UserData?, locale: Locale) -> [InputViewModel] {
        let firstNameModel = createFirstNameViewModel(with: user?.firstName ?? "", locale: locale)
        let lastNameModel = createLastNameViewModel(with: user?.lastName ?? "", locale: locale)
        let phoneModel = createPhoneViewModel(with: user?.phone ?? "", enabled: false, locale: locale)

        return [firstNameModel, lastNameModel, phoneModel]
    }
}
