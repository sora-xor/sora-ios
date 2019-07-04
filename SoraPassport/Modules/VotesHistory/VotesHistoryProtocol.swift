/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood
import SoraUI

typealias VotesHistoryViewModelChange =
SectionedListDifference<VotesHistorySectionViewModel, VotesHistoryItemViewModel>

protocol VotesHistoryViewProtocol: ControllerBackedProtocol {
    func didReload()
    func didReceive(changes: [VotesHistoryViewModelChange])
}

protocol VotesHistoryPresenterProtocol: EmptyStateDelegate {
    func viewIsReady()
    func reload()
    func loadNext() -> Bool

    func numberOfSections() -> Int
    func sectionModel(at index: Int) -> VotesHistorySectionViewModelProtocol
}

protocol VotesHistoryInteractorInputProtocol: class {
	func setup()
    func reload()
    func loadNext(page: Pagination)
}

protocol VotesHistoryInteractorOutputProtocol: class {
    func didReload(events: [VotesHistoryEventData]?)
    func didReceiveVotesHistoryDataProvider(error: Error)

    func didLoadNext(events: [VotesHistoryEventData], for page: Pagination)
    func didReceiveLoadNext(error: Error, for page: Pagination)
}

protocol VotesHistoryWireframeProtocol: ErrorPresentable, AlertPresentable {}

protocol VotesHistoryViewFactoryProtocol: class {
	static func createView() -> VotesHistoryViewProtocol?
}
