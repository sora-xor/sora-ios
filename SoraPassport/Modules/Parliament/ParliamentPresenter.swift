import Foundation
import UIKit

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
            comingSoonDescriptionText: R.string.localizable.tutorialManyWorldDesc(preferredLanguages: languages),
            linkViewModel: LinkViewModel(title: R.string.localizable.commonLearnMore(preferredLanguages: languages), link:  ApplicationConfig.shared.parliamentURL),
            navigationButtonModel: navigationButtonModel,
            image: R.image.promoParliament()
        )

        view?.didReceive(viewModel: viewModel)
    }

    func activateReferenda() {
        wireframe.showReferendaView(from: view)
    }

    func openLink(url: URL?) {
        guard let view = view, let url = url,
              UIApplication.shared.canOpenURL(url) else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .automatic)
    }
}

extension ParliamentPresenter: ParliamentInteractorOutputProtocol {

}
