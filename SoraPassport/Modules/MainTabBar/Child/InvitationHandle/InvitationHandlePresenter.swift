import UIKit
import SoraFoundation

final class InvitationHandlePresenter {
    weak var view: ControllerBackedProtocol?
    var interactor: InvitationHandleInteractorInputProtocol!
    var wireframe: InvitationHandleWireframeProtocol!

    let localizationManager: LocalizationManagerProtocol

    private var userDataResult: Result<UserData, Error>?
    private(set) var pendingInvitationCode: String?

    var logger: LoggerProtocol?

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    private func process() {
        guard let userDataResult = userDataResult else {
            return
        }

        do {
            if let invitationCode = pendingInvitationCode {
                self.pendingInvitationCode = nil

                let userData = try extractValue(result: userDataResult)

                if userData.parentId != nil {
                    throw ApplyInvitationDataError.parentAlreadyExists
                }

                if !userData.canAcceptInvitation {
                    throw ApplyInvitationDataError.invitationAcceptingWindowClosed
                }

                let languages = localizationManager.selectedLocale.rLanguages

                let message = R.string.localizable
                    .inviteEnterConfirmationBodyMask(invitationCode, preferredLanguages: languages)

                let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: languages)
                let cancelAction = AlertPresentableAction(title: cancelTitle)

                let applyTitle = R.string.localizable.commonApply(preferredLanguages: languages)
                let applyAction = AlertPresentableAction(title: applyTitle) { [weak self] in
                    self?.interactor.apply(invitationCode: invitationCode)
                }
//
//                wireframe.present(message: message,
//                                  title: nil,
//                                  actions: [cancelAction, applyAction],
//                                  from: view)
            }
        } catch {
            let locale = localizationManager.selectedLocale

            if !wireframe.present(error: error, from: view, locale: locale) {
                logger?.error("Did receive invitation processing error \(error) after user data")
            }
        }
    }

    private func extractValue<T>(result: Result<T, Error>) throws -> T {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

extension InvitationHandlePresenter: InvitationHandlePresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension InvitationHandlePresenter: InvitationHandleInteractorOutputProtocol {
    func didReceive(userData: UserData) {
        userDataResult = .success(userData)
        process()
    }

    func didReceiveUserDataProvider(error: Error) {
        userDataResult = .failure(error)
        process()
    }

    func didApply(invitationCode: String) {
        let languages = localizationManager.selectedLocale.rLanguages

        wireframe.present(message: R.string.localizable.inviteCodeAppliedBody(preferredLanguages: languages),
                          title: R.string.localizable.inviteCodeAppliedTitle(preferredLanguages: languages),
                          closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                          from: view)
    }

    func didReceiveInvitationApplication(error: Error, of code: String) {
        let locale = localizationManager.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger?.error("Did receive invitation application error \(error)")
        }
    }
}

extension InvitationHandlePresenter {
    func navigate(to invitation: InvitationDeepLink) -> Bool {
        pendingInvitationCode = invitation.code
        interactor.refresh()
        process()

        return true
    }
}
