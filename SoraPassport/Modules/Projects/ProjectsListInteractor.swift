/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class ProjectsListInteractor {
    weak var presenter: ProjectsListInteractorOutputProtocol?

    let projectsDataProvider: DataProvider<ProjectData>
    let referendumsDataProvider: DataProvider<ReferendumData>?
    let eventCenter: EventCenterProtocol

    init(projectsDataProvider: DataProvider<ProjectData>,
         referendumsDataProvider: DataProvider<ReferendumData>?,
         eventCenter: EventCenterProtocol) {
        self.projectsDataProvider = projectsDataProvider
        self.referendumsDataProvider = referendumsDataProvider
        self.eventCenter = eventCenter
    }

    private func setupProjectsDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ProjectData>]) -> Void in
            self?.presenter?.didReceiveProjects(changes: changes)
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveProjectsDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        projectsDataProvider.addObserver(self,
                                         deliverOn: .main,
                                         executing: changesBlock,
                                         failing: failBlock,
                                         options: options)
    }

    private func setupReferendumsDataProvider(_ dataProvider: DataProvider<ReferendumData>) {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ReferendumData>]) -> Void in
            self?.presenter?.didReceiveReferendums(changes: changes)
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveReferendumsDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addObserver(self,
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

        if let referendumsDataProvider = referendumsDataProvider {
            setupReferendumsDataProvider(referendumsDataProvider)
        } else {
            presenter?.didReceiveReferendums(changes: [])
        }
    }

    func refresh() {
        projectsDataProvider.refresh()

        if let referendumsDataProvider = referendumsDataProvider {
            referendumsDataProvider.refresh()
        } else {
            presenter?.didReceiveReferendums(changes: [])
        }
    }
}

extension ProjectsListInteractor: EventVisitorProtocol {
    func processProjectView(event: ProjectViewEvent) {
        presenter?.didViewProject(with: event.projectId)
    }
}
