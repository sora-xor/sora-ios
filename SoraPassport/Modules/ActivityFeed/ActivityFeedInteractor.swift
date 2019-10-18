/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class ActivityFeedInteractor {
	weak var presenter: ActivityFeedInteractorOutputProtocol?

    private(set) var activityFeedDataProvider: SingleValueProvider<ActivityData, CDSingleValue>
    private(set) var announcementDataProvider: SingleValueProvider<AnnouncementData?, CDSingleValue>
    private(set) var projectService: ProjectUnitFundingProtocol

    init(activityFeedDataProvider: SingleValueProvider<ActivityData, CDSingleValue>,
         announcementDataProvider: SingleValueProvider<AnnouncementData?, CDSingleValue>,
         projectService: ProjectUnitFundingProtocol) {
        self.activityFeedDataProvider = activityFeedDataProvider
        self.announcementDataProvider = announcementDataProvider
        self.projectService = projectService
    }

    private func setupAnnouncementDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<AnnouncementData?>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let announcement), .update(let announcement):
                    self?.presenter?.didReload(announcement: announcement)
                case .delete:
                    self?.presenter?.didReload(announcement: nil)
                }
            } else {
                self?.presenter?.didReload(announcement: nil)
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveAnnouncementDataProvider(error: error)
        }

        announcementDataProvider.addCacheObserver(self,
                                                  deliverOn: .main,
                                                  executing: changesBlock,
                                                  failing: failBlock)
    }

    private func setupActivityFeedDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ActivityData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let activity), .update(let activity):
                    self?.presenter?.didReload(activity: activity)
                default:
                    break
                }
            } else {
                self?.presenter?.didReload(activity: nil)
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveActivityFeedDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        activityFeedDataProvider.addCacheObserver(self,
                                                  deliverOn: .main,
                                                  executing: changesBlock,
                                                  failing: failBlock,
                                                  options: options)
    }
}

extension ActivityFeedInteractor: ActivityFeedInteractorInputProtocol {
    func setup() {
        setupActivityFeedDataProvider()
        setupAnnouncementDataProvider()
    }

    func reload() {
        activityFeedDataProvider.refreshCache()
        announcementDataProvider.refreshCache()
    }

    func loadNext(page: Pagination) {
        do {
            _ = try projectService.fetchActivityFeed(with: page,
                                                     runCompletionIn: .main) { [weak self] (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success(let activity):
                        self?.presenter?.didLoadNext(activity: activity, for: page)
                    case .error(let error):
                        self?.presenter?.didReceiveLoadNext(error: error, for: page)
                    }
                }
            }
        } catch {
            presenter?.didReceiveLoadNext(error: error, for: page)
        }
    }
}
