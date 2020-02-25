/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraCrypto
import RobinHood
import SoraFoundation

final class ProjectsViewFactory: ProjectsViewFactoryProtocol {
	static func createView() -> ProjectsViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            Logger.shared.error("Can't create decentralized resolver url")
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = requestSigner

        let voteViewModelFactory = VoteViewModelFactory(amountFormatter: NumberFormatter.vote.localizableResource())

        let view = ProjectsViewController(nib: R.nib.projectsViewController)

        let eventCenter = EventCenter.shared

        let childPresenters = createChildPresenters(with: eventCenter,
                                                    localizationManager: localizationManager)
        let presenter = ProjectsPresenter(children: childPresenters,
                                          voteViewModelFactory: voteViewModelFactory,
                                          votesDisplayFormatter: NumberFormatter.vote.localizableResource())

        childPresenters.forEach { (_, child) in
            child.delegate = presenter
        }

        let wireframe = ProjectsWireframe()

        let interactor = ProjectsInteractor(customerDataProviderFacade: CustomerDataProviderFacade.shared,
                                            projectService: projectService,
                                            eventCenter: eventCenter)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        presenter.localizationManager = localizationManager
        presenter.logger = Logger.shared

        return view
	}

    private static func createChildPresenters(with eventCenter: EventCenterProtocol,
                                              localizationManager: LocalizationManagerProtocol)
        -> [ProjectDisplayType: ProjectsListPresenter] {
        let dataProviderFacade = ProjectDataProviderFacade.shared

        var children = [ProjectDisplayType: ProjectsListPresenter]()
            children[.all] = createProjectListPresenter(viewModelFactory: ProjectViewModelFactory.createDefault(),
                                                        dataProvider: dataProviderFacade.allProjectsProvider,
                                                        eventCenter: eventCenter,
                                                        localizationManager: localizationManager)
        children[.voted] = createProjectListPresenter(viewModelFactory: ProjectViewModelFactory.createDefault(),
                                                      dataProvider: dataProviderFacade.votedProjectsProvider,
                                                      eventCenter: eventCenter,
                                                      localizationManager: localizationManager)
        children[.favorite] = createProjectListPresenter(viewModelFactory: ProjectViewModelFactory.createDefault(),
                                                         dataProvider: dataProviderFacade.favoriteProjectsProvider,
                                                         eventCenter: eventCenter,
                                                         localizationManager: localizationManager)
        children[.completed] = createProjectListPresenter(viewModelFactory: ProjectViewModelFactory.createDefault(),
                                                          dataProvider: dataProviderFacade.finishedProjectsProvider,
                                                          eventCenter: eventCenter,
                                                          localizationManager: localizationManager)

        return children
    }

    private static func createProjectListPresenter(viewModelFactory: ProjectViewModelFactoryProtocol,
                                                   dataProvider: DataProvider<ProjectData>,
                                                   eventCenter: EventCenterProtocol,
                                                   localizationManager: LocalizationManagerProtocol)
        -> ProjectsListPresenter {

        let presenter = ProjectsListPresenter(viewModelFactory: viewModelFactory)
        let interactor = ProjectsListInteractor(projectsDataProvider: dataProvider,
                                                eventCenter: eventCenter)

        presenter.interactor = interactor
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return presenter
    }
}
