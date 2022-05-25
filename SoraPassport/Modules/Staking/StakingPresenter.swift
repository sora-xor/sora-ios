import Foundation
import UIKit

final class StakingPresenter {
    weak var view: StakingViewProtocol?
    var wireframe: StakingWireframeProtocol!
    var interactor: StakingInteractorInputProtocol!
}

extension StakingPresenter: StakingPresenterProtocol {
    func setup(preferredLocalizations languages: [String]?) {

        let linkViewModel = LinkViewModel(
            title: R.string.localizable.commonLearnMore(preferredLanguages: languages),
            link: ApplicationConfig.shared.rewardsURL,
            linkTitleText: nil,
            image: R.image.assetVal()
        )

        let viewModel = ComingSoonViewModel(
            comingSoonText: R.string.localizable.comingSoon(preferredLanguages: languages).uppercased(),
            comingSoonDescriptionText: R.string.localizable.stakingDescription(preferredLanguages: languages),
            linkViewModel: linkViewModel,
            navigationButtonModel: nil,
            image: R.image.promoStaking()
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

extension StakingPresenter: StakingInteractorOutputProtocol {

}
