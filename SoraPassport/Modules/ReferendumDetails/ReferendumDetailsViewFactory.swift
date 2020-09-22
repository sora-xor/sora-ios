import Foundation
import SoraCrypto
import SoraFoundation

final class ReferendumDetailsViewFactory: ReferendumDetailsViewFactoryProtocol {
    static func createView(for referendumId: String) -> ReferendumDetailsViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            Logger.shared.error("Can't create decentralized resolver url")
            return nil
        }

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let detailsProviderFactory = ProjectDetailsDataProviderFactory(requestSigner: requestSigner,
                                                                       projectUnit: projectUnit)
        guard let detailsDataProvider = detailsProviderFactory
            .createReferendumDataProvider(for: referendumId) else {
            Logger.shared.error("Can't create details data provider")
            return nil
        }

        let projectUnitService = ProjectUnitService(unit: projectUnit)
        projectUnitService.requestSigner = requestSigner

        let view = ReferendumDetailsViewController(nib: R.nib.referendumDetailsViewController)

        let voteViewModelFactory = VoteViewModelFactory(amountFormatter: NumberFormatter.vote.localizableResource())

        let referendumViewModelFactory = ReferendumViewModelFactory.createDefault()

        let presenter = ReferendumDetailsPresenter(referendumViewModelFactory: referendumViewModelFactory,
                                                   voteViewModelFactory: voteViewModelFactory,
                                                   votesDisplayFormatter: NumberFormatter.vote)

        let customerProviderFacade = CustomerDataProviderFacade.shared

        let interactor = ReferendumDetailsInteractor(customerDataProviderFacade: customerProviderFacade,
                                                     referendumDetailsDataProvider: detailsDataProvider,
                                                     projectService: projectUnitService,
                                                     eventCenter: EventCenter.shared)
        let wireframe = ReferendumDetailsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        presenter.localizationManager = localizationManager
        view.localizationManager = localizationManager

        presenter.logger = Logger.shared

        return view
    }
}
