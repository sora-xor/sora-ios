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
        let projectsProviderFacade = ProjectDataProviderFacade.shared
        let referendumProviderFacade = ReferendumDataProviderFacade.shared

        let openProjects = projectsProviderFacade.allProjectsProvider
        let openReferendums = referendumProviderFacade.openReferendumsProvider

        let votedProjects = projectsProviderFacade.votedProjectsProvider
        let votedReferendums = referendumProviderFacade.votedReferendumsProvider

        let favoriteProjects = projectsProviderFacade.favoriteProjectsProvider

        let finishedProjects = projectsProviderFacade.finishedProjectsProvider
        let finishedReferendums = referendumProviderFacade.finishedReferendumsProvider

        var children = [ProjectDisplayType: ProjectsListPresenter]()
        children[.all] = createProjectListPresenter(projectsProvider: openProjects,
                                                    referendumsProvider: openReferendums,
                                                    eventCenter: eventCenter,
                                                    localizationManager: localizationManager)
        children[.voted] = createProjectListPresenter(projectsProvider: votedProjects,
                                                      referendumsProvider: votedReferendums,
                                                      eventCenter: eventCenter,
                                                      localizationManager: localizationManager)
        children[.favorite] = createProjectListPresenter(projectsProvider: favoriteProjects,
                                                         referendumsProvider: nil,
                                                         eventCenter: eventCenter,
                                                         localizationManager: localizationManager)
        children[.completed] = createProjectListPresenter(projectsProvider: finishedProjects,
                                                          referendumsProvider: finishedReferendums,
                                                          eventCenter: eventCenter,
                                                          localizationManager: localizationManager)

        return children
    }

    private static func createProjectListPresenter(projectsProvider: DataProvider<ProjectData>,
                                                   referendumsProvider: DataProvider<ReferendumData>?,
                                                   eventCenter: EventCenterProtocol,
                                                   localizationManager: LocalizationManagerProtocol)
        -> ProjectsListPresenter {

        let projectViewModelFactory = ProjectViewModelFactory.createDefault()
        let referendumViewModelFactory = ReferendumViewModelFactory.createDefault()

        let presenter = ProjectsListPresenter(projectsViewModelFactory: projectViewModelFactory,
                                              referendumViewModelFactory: referendumViewModelFactory)
        let interactor = ProjectsListInteractor(projectsDataProvider: projectsProvider,
                                                referendumsDataProvider: referendumsProvider,
                                                eventCenter: eventCenter)

        presenter.interactor = interactor
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return presenter
    }
}
