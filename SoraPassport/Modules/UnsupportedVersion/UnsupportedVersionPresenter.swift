import Foundation

final class UnsupportedVersionPresenter {
    weak var view: UnsupportedVersionViewProtocol?
    var wireframe: UnsupportedVersionWireframeProtocol!
    var interactor: UnsupportedVersionInteractorInputProtocol!

    let supportedVersionData: SupportedVersionData
    let locale: Locale

    var logger: LoggerProtocol?

    init(locale: Locale, supportedVersionData: SupportedVersionData) {
        self.locale = locale
        self.supportedVersionData = supportedVersionData
    }
}

extension UnsupportedVersionPresenter: UnsupportedVersionPresenterProtocol {
    func setup() {
        let title = R.string.localizable
            .commonUnsupportedVersionTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable
            .commonUnsupportedVersionBody(preferredLanguages: locale.rLanguages)
        let actionTitle = R.string.localizable
            .commonUnsupportedVersionAction(preferredLanguages: locale.rLanguages)
        let viewModel = UnsupportedVersionViewModel(title: title,
                                                    message: message,
                                                    icon: R.image.iconAppUpdate(),
                                                    actionTitle: actionTitle)
        view?.didReceive(viewModel: viewModel)
    }

    func performAction() {
        if let url = supportedVersionData.updateUrl {
            if !wireframe.open(url: url) {
                let message = R.string.localizable
                    .urlNoAppErrorMessage(preferredLanguages: locale.rLanguages)
                let title = R.string.localizable
                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages)
                let closeAction = R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
                wireframe.present(message: message,
                                  title: title,
                                  closeAction: closeAction,
                                  from: view)
            }
        } else {
            logger?.warning("Update application url is empty")
        }
    }
}

extension UnsupportedVersionPresenter: UnsupportedVersionInteractorOutputProtocol {}
