/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class ProfilePresenter {
	weak var view: ProfileViewProtocol?
	var interactor: ProfileInteractorInputProtocol!
	var wireframe: ProfileWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var viewModelFactory: ProfileViewModelFactoryProtocol

    private(set) var userData: UserData?
    private(set) var votesData: VotesData?
    private(set) var reputationData: ReputationData?
    private(set) var termsData: WebData

    init(viewModelFactory: ProfileViewModelFactoryProtocol, termsData: WebData) {
        self.viewModelFactory = viewModelFactory
        self.termsData = termsData
    }

    private func refreshData() {
        interactor.refreshUser()
        interactor.refreshVotes()
        interactor.refreshReputation()
    }

    private func updateUserDetailsViewModel() {
        let userDetailsViewModel = viewModelFactory.createUserViewModel(from: userData)
        view?.didLoad(userViewModel: userDetailsViewModel)
    }

    private func updateOptionsViewModel() {
        let optionViewModels = viewModelFactory.createOptionViewModels(from: votesData,
                                                                       reputationData: reputationData)
        view?.didLoad(optionViewModels: optionViewModels)
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {
    func viewIsReady() {
        updateUserDetailsViewModel()
        updateOptionsViewModel()

        interactor.setup()
    }

    func viewDidAppear() {
        refreshData()
    }

    func activateUserDetails() {
        wireframe.showPersonalDetailsView(from: view)
    }

    func activateOption(at index: UInt) {
        guard let option = ProfileOption(rawValue: index) else {
            return
        }

        switch option {
        case .reputation:
            wireframe.showReputationView(from: view)
        case .votes:
            wireframe.showVotesHistoryView(from: view)
        case .personalDetails:
            wireframe.showPersonalDetailsView(from: view)
        case .passphrase:
            wireframe.showPassphraseView(from: view)
        case .terms:
            if let view = view {
                wireframe.showWeb(url: termsData.url,
                                  from: view,
                                  secondaryTitle: termsData.title)
            }
        }
    }

    func activateHelp() {
        wireframe.presentHelp(from: view)
    }
}

extension ProfilePresenter: ProfileInteractorOutputProtocol {
    func didReceive(userData: UserData) {
        self.userData = userData
        updateUserDetailsViewModel()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive user data provider \(error)")
    }

    func didReceive(votesData: VotesData) {
        self.votesData = votesData
        updateOptionsViewModel()
    }

    func didReceiveVotesDataProvider(error: Error) {
        logger?.debug("Did receive votes data provider \(error)")
    }

    func didReceive(reputationData: ReputationData) {
        self.reputationData = reputationData
        updateOptionsViewModel()
    }

    func didReceiveReputationDataProvider(error: Error) {
        logger?.debug("Did receive reputation data provider \(error)")
    }
}
