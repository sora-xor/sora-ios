import Foundation
@testable import SoraPassport

final class PersonalUpdateWireframeMock: PersonalUpdateWireframeProtocol {
    var numberOfCloseCalled: Int = 0
    var numberOfErrorPresentationCalled: Int = 0
    var numberOfAlertPresentationCalled: Int = 0

    var closeCalledBlock: (() -> Void)?
    var alertPresentationCalledBlock: (() -> Void)?
    var errorPresentationCalledBlock: (() -> Void)?

    func close(view: PersonalUpdateViewProtocol?) {
        numberOfCloseCalled += 1

        closeCalledBlock?()
    }

    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) {
        numberOfAlertPresentationCalled += 1

        alertPresentationCalledBlock?()
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        numberOfErrorPresentationCalled += 1

        errorPresentationCalledBlock?()

        return true
    }
}
