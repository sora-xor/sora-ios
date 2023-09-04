import UIKit
import SoraFoundation

final class NetworkAvailabilityLayerPresenter {
    var view: ApplicationStatusPresentable!
    weak var interactor: NetworkAvailabilityLayerInteractorInputProtocol!

    var unavailbleStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: R.color.statusError()!,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.styled(for: .paragraph3))
    }

    var availableStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: R.color.statusWarningBackground()!,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.styled(for: .paragraph3))
    }
}

extension NetworkAvailabilityLayerPresenter: NetworkAvailabilityLayerInteractorOutputProtocol {

    func didDecideUnreachableNodesAllertPresentation() {

        let languages = localizationManager?.preferredLocalizations
        let alert = UIAlertController(
            title: R.string.localizable.nodeOffline(preferredLanguages: languages),
            message: R.string.localizable.nodeConnectionIssue(preferredLanguages: languages),
            preferredStyle: .alert
        )
        alert.addAction(.init(title: R.string.localizable.commonClose(preferredLanguages: languages), style: .cancel))

        view.presentAlert(alert: alert, animated: true)
    }

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
