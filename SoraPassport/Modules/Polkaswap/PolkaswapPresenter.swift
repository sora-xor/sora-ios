import Foundation
import UIKit

final class PolkaswapPresenter {
    weak var view: PolkaswapViewProtocol?
    var wireframe: PolkaswapWireframeProtocol!
    var interactor: PolkaswapInteractorInputProtocol!
}

extension PolkaswapPresenter: PolkaswapPresenterProtocol {
    func setup(preferredLocalizations languages: [String]?) {
        let linkViewModel = LinkViewModel(
            title: R.string.localizable.aboutWebsite(preferredLanguages: languages),
            link: ApplicationConfig.shared.polkaswapURL,
            linkTitleText: "Polkaswap.io",
            image: R.image.tabBar.polkaswap()
        )

        let viewModel = ComingSoonViewModel(
            comingSoonText: R.string.localizable.comingSoon(preferredLanguages: languages).uppercased(),
            comingSoonDescriptionText: R.string.localizable.polkaswapComingSoon(preferredLanguages: languages),
            linkViewModel: linkViewModel,
            navigationButtonModel: nil
        )

        view?.didReceive(viewModel: viewModel)
    }

    func openLink(url: URL?) {
        guard let view = view, let url = url,
              UIApplication.shared.canOpenURL(url) else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .automatic)
    }
}

extension PolkaswapPresenter: PolkaswapInteractorOutputProtocol {

}
