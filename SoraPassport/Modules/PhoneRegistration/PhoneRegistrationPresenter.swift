import Foundation

final class PhoneRegistrationPresenter {
    weak var view: PhoneRegistrationViewProtocol?
    var wireframe: PhoneRegistrationWireframeProtocol!
    var interactor: PhoneRegistrationInteractorInputProtocol!

    let country: Country

    private(set) var viewModel: PersonalInfoViewModel

    init(country: Country) {
        self.country = country

        viewModel = PersonalInfoViewModel(title: R.string.localizable.phoneRegistrationInputTitle(),
                                          value: country.dialCode,
                                          enabled: true,
                                          minLength: country.dialCode.count,
                                          maxLength: PersonalInfoSharedConstants.phoneLimit,
                                          validCharacterSet: CharacterSet.decimalDigits,
                                          predicate: NSPredicate.phone)
    }
}

extension PhoneRegistrationPresenter: PhoneRegistrationPresenterProtocol {
    func setup() {
        view?.didReceive(viewModel: viewModel)
    }

    func processPhoneInput() {
        view?.didStartLoading()

        let userCreationInfo = UserCreationInfo(phone: viewModel.value)

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

        if wireframe.present(error: error, from: view) {
            return
        }
    }
}
