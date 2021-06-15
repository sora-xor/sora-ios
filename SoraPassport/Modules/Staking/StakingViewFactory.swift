import Foundation
import SoraFoundation

final class StakingViewFactory: StakingViewFactoryProtocol {
    static func createView() -> StakingViewProtocol? {
        let view = StakingViewController(nib: R.nib.stakingViewController)
        view.localizationManager = LocalizationManager.shared

        let presenter = StakingPresenter()
        let interactor = StakingInteractor()
        let wireframe = StakingWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
