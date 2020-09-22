import Foundation
import SoraFoundation

final class ReputationPresenter {
	weak var view: ReputationViewProtocol?
	var interactor: ReputationInteractorInputProtocol!
	var wireframe: ReputationWireframeProtocol!

    let viewModelFactory: ReputationViewModelFactoryProtocol
    let reputationDelayFactory: ReputationDelayFactoryProtocol
    let votesFormatter: NumberFormatter
    let integerFormatter: NumberFormatter
    let locale: Locale

    private lazy var timer: CountdownTimerProtocol = {
        return CountdownTimer(delegate: self)
    }()

    var logger: LoggerProtocol?

    init(locale: Locale,
         viewModelFactory: ReputationViewModelFactoryProtocol,
         reputationDelayFactory: ReputationDelayFactoryProtocol,
         votesFormatter: NumberFormatter,
         integerFormatter: NumberFormatter) {
        self.locale = locale
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter

        self.viewModelFactory = viewModelFactory
        self.reputationDelayFactory = reputationDelayFactory
    }
}

extension ReputationPresenter: ReputationPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func viewDidAppear() {
        interactor.refresh()
    }
}

extension ReputationPresenter: ReputationInteractorOutputProtocol {
    func didReceive(reputationData: ReputationData) {
        if  let rank = reputationData.rank,
            let rankString = integerFormatter.string(from: NSNumber(value: rank)),
            let ranksCount = reputationData.ranksCount,
            let ranksCountString = integerFormatter.string(from: NSNumber(value: ranksCount)) {

            timer.stop()

            let details = R.string.localizable
                .reputationTotalRankTemplate(rankString,
                                             ranksCountString,
                                             preferredLanguages: locale.rLanguages)

            view?.set(existingRankDetails: details)

        } else {
            let remainingTime = reputationDelayFactory.calculateDelay(from: Date())
            timer.start(with: remainingTime)
        }
    }

    func didReceiveReputationDataProvider(error: Error) {
        logger?.debug("Did receive reputation data provider \(error)")
    }

    func didReceive(reputationDetails: ReputationDetailsData) {
        do {
            let viewModel = try viewModelFactory
                .createReputationDetailsViewModel(from: reputationDetails)
            view?.set(reputationDetailsViewModel: viewModel)
        } catch {
            logger?.error("Can't create reputation details \(error)")
        }
    }

    func didReceiveReputationDetailsDataProvider(error: Error) {
        logger?.debug("Did receive reputation details provider \(error)")
    }

    func didReceive(votesData: VotesData) {
        if let lastVotes = votesData.lastReceived, let decimalVotes = Decimal(string: lastVotes),
            let formattedVotes = votesFormatter.string(from: decimalVotes as NSNumber) {
            let votesDetails = R.string.localizable
                .reputationLastVotesTemplate(formattedVotes, preferredLanguages: locale.rLanguages)
            view?.set(votesDetails: votesDetails)
        }
    }

    func didReceiveVotesDataProvider(error: Error) {
        logger?.error("Did receive votes data provider error \(error)")
    }
}

extension ReputationPresenter: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        let details = viewModelFactory.createEmptyRankTitle(for: interval,
                                                            locale: locale)
        view?.set(emptyRankDetails: details)
    }

    func didCountdown(remainedInterval: TimeInterval) {
        let details = viewModelFactory.createEmptyRankTitle(for: remainedInterval,
                                                            locale: locale)
        view?.set(emptyRankDetails: details)
    }

    func didStop(with remainedInterval: TimeInterval) {
        let details = viewModelFactory.createEmptyRankTitle(for: remainedInterval,
                                                            locale: locale)
        view?.set(emptyRankDetails: details)

        interactor.refresh()
    }
}
