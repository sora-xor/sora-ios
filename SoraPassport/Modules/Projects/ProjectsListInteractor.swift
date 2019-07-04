/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class ProjectsListInteractor {
    weak var presenter: ProjectsListInteractorOutputProtocol?

    private(set) var projectsDataProvider: DataProvider<ProjectData, CDProject>

    init(projectsDataProvider: DataProvider<ProjectData, CDProject>) {
        self.projectsDataProvider = projectsDataProvider
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
}

extension ProjectsListInteractor: ProjectsListInteractorInputProtocol {
    func setup() {
        setupProjectsDataProvider()
    }

    func refresh() {
        projectsDataProvider.refreshCache()
    }
}
