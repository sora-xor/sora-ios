protocol ReferendumDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(votes: String)
    func didReceive(referendum: ReferendumDetailsViewModelProtocol)
}

protocol ReferendumDetailsPresenterProtocol: class {
    func setup()
    func activateVotes()
    func activateClose()
    func supportReferendum()
    func unsupportReferendum()
    func handleElapsedTime()
}

protocol ReferendumDetailsInteractorInputProtocol: class {
    func setup()
    func refreshVotes()
    func refreshDetails()
    func vote(for referendum: ReferendumVote)
}

protocol ReferendumDetailsInteractorOutputProtocol: class {
    func didReceive(votes: VotesData)
    func didReceiveVotesDataProvider(error: Error)

    func didReceive(referendum: ReferendumData?)
    func didReceiveReferendumDataProvider(error: Error)

    func didVote(for referendum: ReferendumVote)
    func didReceiveVote(error: Error, for referendum: ReferendumVote)
}

protocol ReferendumDetailsWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showVotingView(from view: ReferendumDetailsViewProtocol?,
                        with model: VoteViewModelProtocol,
                        style: VoteViewStyle,
                        delegate: VoteViewDelegate?)

    func close(view: ReferendumDetailsViewProtocol?)

    func showVotesHistoryView(from view: ReferendumDetailsViewProtocol?)
}

protocol ReferendumDetailsViewFactoryProtocol: class {
    static func createView(for referendumId: String) -> ReferendumDetailsViewProtocol?
}
