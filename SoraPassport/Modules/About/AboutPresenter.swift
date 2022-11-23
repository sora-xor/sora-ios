import Foundation
import SoraFoundation

final class AboutPresenter {
    weak var view: AboutViewProtocol?
    var wireframe: AboutWireframeProtocol!

    private(set) var viewModelFactory: AboutViewModelFactoryProtocol

    init(viewModelFactory: AboutViewModelFactory) {
        self.viewModelFactory = viewModelFactory
    }
}

extension AboutPresenter: AboutPresenterProtocol {

    func setup() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let optionViewModels = viewModelFactory.createAboutViewModels(locale: locale)

        view?.didReceive(optionViewModels: optionViewModels)
    }

    func activateOption(_ option: AboutOption) {
        switch option {
        case .website, .opensource, .telegram, .terms, .privacy, .medium, .announcements, .support, .twitter, .instagram, .youtube, .wiki:
            show(url: option.address())

        case .writeUs(let email):
            activateWriteUs(to: email)
        }
    }
}

private extension AboutPresenter {

    func show(url: URL?) {
        if let view = view, let url = url {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }

    func activateWriteUs(to email: String) {
        guard let view = view else {
            return
        }

        let message = SocialMessage(
            body: nil, subject: nil,
            recepients: [email]
        )

        if !wireframe.writeEmail(with: message, from: view, completionHandler: nil) {
            wireframe.present(
                message: R.string.localizable.noEmailBoundErrorMessage(preferredLanguages: languages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                from: view
            )
        }
    }
}

extension AboutPresenter: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {

    }
}
