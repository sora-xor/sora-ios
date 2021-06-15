import Foundation

final class ParliamentPresenter {
    weak var view: ParliamentViewProtocol?
    var wireframe: ParliamentWireframeProtocol!
    var interactor: ParliamentInteractorInputProtocol!
}

extension ParliamentPresenter: ParliamentPresenterProtocol {
    func setup(preferredLocalizations languages: [String]?) {

        let navigationButtonModel = NavigationButtonModel(
            title: R.string.localizable.referendaTitle(preferredLanguages: languages),
            description: R.string.localizable.referendaTitleVote(preferredLanguages: languages)
        )

        let viewModel = ComingSoonViewModel(
            comingSoonText: R.string.localizable.comingSoon(preferredLanguages: languages).uppercased(),
            comingSoonDescriptionText: R.string.localizable.parliamentComingSoon(preferredLanguages: languages),
            linkViewModel: nil,
            navigationButtonModel: navigationButtonModel
        )

        view?.didReceive(viewModel: viewModel)
    }

    func activateReferenda() {
        wireframe.showReferendaView(from: view)
    }
}

extension ParliamentPresenter: ParliamentInteractorOutputProtocol {

}
