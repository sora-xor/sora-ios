import Foundation

protocol ReputationViewProtocol: ControllerBackedProtocol {
    func set(emptyRankDetails: String)
    func set(existingRankDetails: String)
    func set(votesDetails: String)
    func set(reputationDetailsViewModel: ReputationDetailsViewModel)
}

protocol ReputationPresenterProtocol: class {
    func setup()
    func viewDidAppear()
}

protocol ReputationInteractorInputProtocol: class {
    func setup()
    func refresh()
}

protocol ReputationInteractorOutputProtocol: class {
    func didReceive(reputationData: ReputationData)
    func didReceiveReputationDataProvider(error: Error)
    func didReceive(reputationDetails: ReputationDetailsData)
    func didReceiveReputationDetailsDataProvider(error: Error)
    func didReceive(votesData: VotesData)
    func didReceiveVotesDataProvider(error: Error)
}

protocol ReputationWireframeProtocol: ErrorPresentable, AlertPresentable {}

protocol ReputationViewFactoryProtocol: class {
	static func createView() -> ReputationViewProtocol?
}
