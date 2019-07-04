/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol ReputationViewProtocol: ControllerBackedProtocol {
    func didReceiveRank(details: String)
    func didReceiveVotes(details: String)
}

protocol ReputationPresenterProtocol: class {
    func viewIsReady()
    func viewDidAppear()
}

protocol ReputationInteractorInputProtocol: class {
    func setup()
    func refreshReputation()
}

protocol ReputationInteractorOutputProtocol: class {
    func didReceive(reputationData: ReputationData)
    func didReceiveReputationDataProvider(error: Error)
    func didReceive(votesData: VotesData)
    func didReceiveVotesDataProvider(error: Error)
}

protocol ReputationWireframeProtocol: ErrorPresentable, AlertPresentable {}

protocol ReputationViewFactoryProtocol: class {
	static func createView() -> ReputationViewProtocol?
}
