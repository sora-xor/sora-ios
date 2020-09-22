/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol)
    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])
}

protocol ProfilePresenterProtocol: class {
    func setup()
    func viewDidAppear()
    func activateUserDetails()
    func activateOption(at index: UInt)
    func activateHelp()
}

protocol ProfileInteractorInputProtocol: class {
    func setup()
    func refreshUser()
    func refreshVotes()
    func refreshReputation()
}

protocol ProfileInteractorOutputProtocol: class {
    func didReceive(userData: UserData)
    func didReceiveUserDataProvider(error: Error)

    func didReceive(votesData: VotesData)
    func didReceiveVotesDataProvider(error: Error)

    func didReceive(reputationData: ReputationData)
    func didReceiveReputationDataProvider(error: Error)
}

protocol ProfileWireframeProtocol: ErrorPresentable, AlertPresentable, HelpPresentable, WebPresentable {
    func showReputationView(from view: ProfileViewProtocol?)
    func showVotesHistoryView(from view: ProfileViewProtocol?)
    func showPersonalDetailsView(from view: ProfileViewProtocol?)
    func showPassphraseView(from view: ProfileViewProtocol?)
    func showLanguageSelection(from view: ProfileViewProtocol?)
    func showAbout(from view: ProfileViewProtocol?)
}

protocol ProfileViewFactoryProtocol: class {
	static func createView() -> ProfileViewProtocol?
}
