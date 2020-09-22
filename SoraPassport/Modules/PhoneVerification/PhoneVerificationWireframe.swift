import Foundation

final class PhoneVerificationWireframe: PhoneVerificationWireframeProtocol {
    let form: PersonalForm

    init(form: PersonalForm) {
        self.form = form
    }

    func showNext(from view: PhoneVerificationViewProtocol?) {
        guard let registrationView = PersonalInfoViewFactory.createView(with: form) else {
            return
        }

        if let navigationCountroller = view?.controller.navigationController {
            navigationCountroller.pushViewController(registrationView.controller, animated: true)
        }
    }
}
