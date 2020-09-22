import Foundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var interactor: OnboardingMainInputInteractorProtocol!
    var wireframe: OnboardingMainWireframeProtocol!

    let legalData: LegalData

    let locale: Locale

    private func provideTutorialViewModels() {
        var viewModels: [TutorialViewModel] = []

        let projectInitialDescription = R.string.localizable
            .tutorialProjectsDesc(preferredLanguages: locale.rLanguages)
        viewModels.append(TutorialViewModel(details: projectInitialDescription,
                                            imageName: R.image.tutorial1.name))

        let votesDescription = R.string.localizable
            .tutorialVotesDesc(preferredLanguages: locale.rLanguages)
        viewModels.append(TutorialViewModel(details: votesDescription,
                                            imageName: R.image.tutorial2.name))

        let projectFundDescription = R.string.localizable
            .tutorialProjectSuccessDesc(preferredLanguages: locale.rLanguages)
        viewModels.append(TutorialViewModel(details: projectFundDescription,
                                            imageName: R.image.tutorial3.name))

        view?.didReceive(viewModels: viewModels)
    }

    init(legalData: LegalData, locale: Locale) {
        self.legalData = legalData
        self.locale = locale
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func activateTerms() {
        if let view = view {
            wireframe.showWeb(url: legalData.termsUrl,
                              from: view,
                              style: .modal)
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(url: legalData.privacyPolicyUrl,
                              from: view,
                              style: .modal)
        }
    }

    func setup() {
        provideTutorialViewModels()

        interactor.setup()
    }

    func activateSignup() {
        interactor.prepareSignup()
    }

    func activateAccountRestore() {
        interactor.prepareRestore()
    }
}

extension OnboardingMainPresenter: OnboardingMainOutputInteractorProtocol {
    func didStartSignupPreparation() {
        view?.didStartLoading()
    }

    func didFinishSignupPreparation() {
        view?.didStopLoading()
        wireframe.showSignup(from: view)
    }

    func didReceiveSignupPreparation(error: Error) {
        view?.didStopLoading()
        _ = wireframe.present(error: error, from: view, locale: locale)
    }

    func didStartRestorePreparation() {
        view?.didStartLoading()
    }

    func didFinishRestorePreparation() {
        view?.didStopLoading()
        wireframe.showAccountRestore(from: view)
    }

    func didReceiveRestorePreparation(error: Error) {
        view?.didStopLoading()
        _ = wireframe.present(error: error, from: view, locale: locale)
    }

    func didReceiveVersion(data: SupportedVersionData) {
        if !data.supported {
            view?.didStopLoading()

            wireframe.presentUnsupportedVersion(for: data, on: view?.controller.view.window, animated: true)
        }
    }
}
