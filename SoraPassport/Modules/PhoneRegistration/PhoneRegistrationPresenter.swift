import Foundation
import SoraFoundation

final class PhoneRegistrationPresenter {
    weak var view: PhoneRegistrationViewProtocol?
    var wireframe: PhoneRegistrationWireframeProtocol!
    var interactor: PhoneRegistrationInteractorInputProtocol!

    let country: Country
    let locale: Locale

    private(set) var viewModel: InputViewModelProtocol

    init(locale: Locale, country: Country) {
        self.country = country
        self.locale = locale

        let title = R.string.localizable.phoneNumberMobile(preferredLanguages: locale.rLanguages)

        let inputHandler = InputHandler(value: country.dialCode,
                                        minLength: country.dialCode.count,
                                        maxLength: PersonalInfoSharedConstants.phoneLimit,
                                        validCharacterSet: CharacterSet.decimalDigits,
                                        predicate: NSPredicate.phone)

        viewModel = InputViewModel(inputHandler: inputHandler, title: title)
    }
}

extension PhoneRegistrationPresenter: PhoneRegistrationPresenterProtocol {
    func setup() {
        view?.didReceive(viewModel: viewModel)
    }

    func processPhoneInput() {
        view?.didStartLoading()

        let userCreationInfo = UserCreationInfo(phone: viewModel.inputHandler.normalizedValue)

        interactor.createCustomer(with: userCreationInfo)
    }
}

extension PhoneRegistrationPresenter: PhoneRegistrationInteractorOutputProtocol {
    func didCreateCustomer() {
        view?.didStopLoading()

        wireframe.showPhoneVerification(from: view, country: country)
    }

    func didReceiveCustomerCreation(error: Error) {
        view?.didStopLoading()

        if let userCreationError = error as? UserCreationError, userCreationError == .verified {
            wireframe.showRegistration(from: view, country: country)
            return
        }

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }
    }
}
