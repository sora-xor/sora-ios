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
    func setup()
    func reload()
    func loadNext() -> Bool

    func numberOfSections() -> Int
    func sectionModel(at index: Int) -> VotesHistorySectionViewModelProtocol
}

protocol VotesHistoryInteractorInputProtocol: class {
	func setup()
    func reload()
    func loadNext(page: OffsetPagination)
}

protocol VotesHistoryInteractorOutputProtocol: class {
    func didReload(events: [VotesHistoryEventData]?)
    func didReceiveVotesHistoryDataProvider(error: Error)

    func didLoadNext(events: [VotesHistoryEventData], for page: OffsetPagination)
    func didReceiveLoadNext(error: Error, for page: OffsetPagination)
}

protocol VotesHistoryWireframeProtocol: ErrorPresentable, AlertPresentable {}

protocol VotesHistoryViewFactoryProtocol: class {
	static func createView() -> VotesHistoryViewProtocol?
}
