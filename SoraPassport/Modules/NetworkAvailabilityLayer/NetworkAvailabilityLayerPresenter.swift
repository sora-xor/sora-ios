import UIKit
import SoraFoundation

final class NetworkAvailabilityLayerPresenter {
    var view: ApplicationStatusPresentable!
    weak var interactor: NetworkAvailabilityLayerInteractorInputProtocol!

    var unavailbleStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: UIColor.networkUnavailableBackground,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.statusTitle)
    }

    var availableStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: UIColor.networkAvailableBackground,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.statusTitle)
    }
}

extension NetworkAvailabilityLayerPresenter: NetworkAvailabilityLayerInteractorOutputProtocol {
    func didDecideUnreachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.presentStatus(title: R.string.localizable
            .networkUnavailable(preferredLanguages: languages),
                           style: unavailbleStyle,
                           animated: true)
    }

    func didDecideReachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.dismissStatus(title: R.string.localizable
            .networkAvailable(preferredLanguages: languages),
                           style: availableStyle,
                           animated: true)
    }
}

extension NetworkAvailabilityLayerPresenter: Localizable {
    func applyLocalization() {}
}
