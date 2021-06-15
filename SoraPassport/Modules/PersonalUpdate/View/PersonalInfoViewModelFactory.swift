import Foundation
import SoraFoundation

protocol PersonalInfoViewModelFactoryProtocol {
    func createRegistrationForm(from form: PersonalForm, locale: Locale) -> [InputViewModel]
    func createViewModels(from username: String?, locale: Locale) -> [InputViewModel]
}

final class PersonalInfoViewModelFactory {

    private func createUsernameViewModel(with value: String, locale: Locale) -> InputViewModel {
        let title = R.string.localizable.personalInfoUsername(preferredLanguages: locale.rLanguages)

        let inputHandler = InputHandler(
            value: value,
            required: false,
            maxLength: PersonalInfoSharedConstants.usernameMaxLengthInBytes
        )

        return InputViewModel(inputHandler: inputHandler, title: title, autocapitalization: .words)
    }

    private func updateUsernameViewModel(with value: String, locale: Locale) -> InputViewModel {
        let title = R.string.localizable.personalInfoUsernameV1(preferredLanguages: locale.rLanguages)

        let inputHandler = InputHandler(
            value: value,
            required: false,
            maxLength: PersonalInfoSharedConstants.usernameMaxLengthInBytes
        )

        return InputViewModel(inputHandler: inputHandler, title: title, autocapitalization: .words)
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
        let invitationCode = createInvitationCodeViewModel(
            with: form.invitationCode ?? "", locale: locale)
        let usernameModel = createUsernameViewModel(with: form.username, locale: locale)

        return [usernameModel, invitationCode]
    }

    func createViewModels(from username: String?, locale: Locale) -> [InputViewModel] {
        let usernameModel = updateUsernameViewModel(with: username ?? "", locale: locale)

        return [usernameModel]
    }
}
