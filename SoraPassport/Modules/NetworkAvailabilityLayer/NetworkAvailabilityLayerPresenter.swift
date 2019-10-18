import UIKit

final class NetworkAvailabilityLayerPresenter {
    var view: ApplicationStatusPresentable!
    weak var interactor: NetworkAvailabilityLayerInteractorInputProtocol!

    var unavailbleStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: UIColor.networkUnavailableBackground,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.statusTitle)
    }

    var availbleStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: UIColor.networkAvailableBackground,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.statusTitle)
    }
}

extension NetworkAvailabilityLayerPresenter: NetworkAvailabilityLayerInteractorOutputProtocol {
    func didDecideUnreachableStatusPresentation() {
        view.presentStatus(title: R.string.localizable.networkUnavailable(),
                           style: unavailbleStyle,
                           animated: true)
    }

    func didDecideReachableStatusPresentation() {
        view.dismissStatus(title: R.string.localizable.networkAvailable(),
                           style: availbleStyle,
                           animated: true)
    }
}
