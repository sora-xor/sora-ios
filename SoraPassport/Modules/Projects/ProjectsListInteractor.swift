/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class ProjectsListInteractor {
    weak var presenter: ProjectsListInteractorOutputProtocol?

    let projectsDataProvider: DataProvider<ProjectData, CDProject>
    let eventCenter: EventCenterProtocol

    init(projectsDataProvider: DataProvider<ProjectData, CDProject>,
         eventCenter: EventCenterProtocol) {
        self.projectsDataProvider = projectsDataProvider
        self.eventCenter = eventCenter
    }

    private func setupProjectsDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ProjectData>]) -> Void in
            self?.presenter?.didReceiveProjects(changes: changes, at: 0)
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveProjectsDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        projectsDataProvider.addCacheObserver(self,
                                              deliverOn: .main,
                                              executing: changesBlock,
                                              failing: failBlock,
                                              options: options)
    }

    private func setupEventCenter() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension ProjectsListInteractor: ProjectsListInteractorInputProtocol {
    func setup() {
        setupEventCenter()
        setupProjectsDataProvider()
    }

    func refresh() {
        projectsDataProvider.refreshCache()
    }
}

extension ProjectsListInteractor: EventVisitorProtocol {
    func processProjectView(event: ProjectViewEvent) {
        presenter?.didViewProject(with: event.projectId)
    }
}
