/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraCrypto
import SoraUI
import SoraFoundation

final class ProjectDetailsViewFactory: ProjectDetailsViewFactoryProtocol {
	static func createView(for projectId: String) -> ProjectDetailsViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            Logger.shared.error("Can't create decentralized resolver url")
            return nil
        }

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let detailsProviderFactory = ProjectDetailsDataProviderFactory(requestSigner: requestSigner,
                                                                       projectUnit: projectUnit)
        guard let detailsDataProvider = detailsProviderFactory.createDetailsDataProvider(for: projectId) else {
            Logger.shared.error("Can't create details data provider")
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let projectUnitService = ProjectUnitService(unit: projectUnit)
        projectUnitService.requestSigner = requestSigner

        let view = ProjectDetailsViewController(nib: R.nib.projectDetailsViewController)
        view.favoriteAnimator = SpringAnimator(initialScale: 1.2)
        view.changesAnimator = BlockViewAnimator(duration: 0.2, delay: 0.0, options: .curveLinear)

        let voteViewModelFactory = VoteViewModelFactory(amountFormatter: NumberFormatter.vote.localizableResource())
        let projectViewModelFactory = ProjectViewModelFactory.createDefault()

        let presenter = ProjectDetailsPresenter(projectDetailsViewModelFactory: projectViewModelFactory,
                                                voteViewModelFactory: voteViewModelFactory,
                                                votesDisplayFormatter: NumberFormatter.vote)

        let interactor = ProjectDetailsInteractor(customerDataProviderFacade: CustomerDataProviderFacade.shared,
                                                  projectDetailsDataProvider: detailsDataProvider,
                                                  projectService: projectUnitService,
                                                  eventCenter: EventCenter.shared)

        let wireframe = ProjectDetailsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        presenter.logger = Logger.shared
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
