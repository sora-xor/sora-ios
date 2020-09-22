/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraUI

protocol ActivityFeedViewProtocol: ControllerBackedProtocol {
    var itemLayoutMetadataContainer: ActivityFeedLayoutMetadataContainer { get }
    var announcementLayoutMetadata: AnnouncementItemLayoutMetadata { get }

    func didReceive(using viewModelChangeBlock: @escaping () -> ActivityFeedStateChange)
    func didReload(announcement: AnnouncementItemViewModelProtocol?)
}

protocol ActivityFeedPresenterProtocol: class {
    func setup()
    func viewDidAppear()
    func reload() -> Bool
    func loadNext() -> Bool

    func numberOfSections() -> Int
    func sectionModel(at index: Int) -> ActivityFeedSectionViewModelProtocol

    func activateHelp()
}

protocol ActivityFeedInteractorInputProtocol: class {
    func setup()
    func reload()
    func loadNext(page: OffsetPagination)
}

protocol ActivityFeedInteractorOutputProtocol: class {
    func didReload(activity: ActivityData?)
    func didReceiveActivityFeedDataProvider(error: Error)

    func didLoadNext(activity: ActivityData, for page: OffsetPagination)
    func didReceiveLoadNext(error: Error, for page: OffsetPagination)

    func didReload(announcement: AnnouncementData?)
    func didReceiveAnnouncementDataProvider(error: Error)
}

protocol ActivityFeedWireframeProtocol: ErrorPresentable, AlertPresentable, HelpPresentable {}

protocol ActivityFeedViewFactoryProtocol: class {
	static func createView() -> ActivityFeedViewProtocol?
}
