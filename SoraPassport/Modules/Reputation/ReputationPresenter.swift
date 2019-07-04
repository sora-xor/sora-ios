/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class ReputationPresenter {
	weak var view: ReputationViewProtocol?
	var interactor: ReputationInteractorInputProtocol!
	var wireframe: ReputationWireframeProtocol!

    private(set) var votesFormatter: NumberFormatter
    private(set) var integerFormatter: NumberFormatter

    var logger: LoggerProtocol?

    init(votesFormatter: NumberFormatter, integerFormatter: NumberFormatter) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
    }
}

extension ReputationPresenter: ReputationPresenterProtocol {
    func viewIsReady() {
        interactor.setup()
    }

    func viewDidAppear() {
        interactor.refreshReputation()
    }
}

extension ReputationPresenter: ReputationInteractorOutputProtocol {
    func didReceive(reputationData: ReputationData) {
        if  let rank = reputationData.rank,
            let rankString = integerFormatter.string(from: NSNumber(value: rank)),
            let ranksCount = reputationData.ranksCount,
            let ranksCountString = integerFormatter.string(from: NSNumber(value: ranksCount)) {

            let details = R.string.localizable.reputationDetailsFormat(rankString, ranksCountString)

            view?.didReceiveRank(details: details)

        } else {
            let details = R.string.localizable.reputationDetailsNoUser()
            view?.didReceiveRank(details: details)
        }
    }

    func didReceiveReputationDataProvider(error: Error) {
        logger?.debug("Did receive reputation data provider \(error)")
    }

    func didReceive(votesData: VotesData) {
        if let lastVotes = votesData.lastReceived, let decimalVotes = Decimal(string: lastVotes),
            let formattedVotes = votesFormatter.string(from: decimalVotes as NSNumber) {
            let votesDetails = R.string.localizable.reputationVotesDetails(formattedVotes)
            view?.didReceiveVotes(details: votesDetails)
        }
    }

    func didReceiveVotesDataProvider(error: Error) {
        logger?.error("Did receive votes data provider error \(error)")
    }
}
