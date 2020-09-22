/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

final class ReferendumDetailsPresenter {
    weak var view: ReferendumDetailsViewProtocol?
    var wireframe: ReferendumDetailsWireframeProtocol!
    var interactor: ReferendumDetailsInteractorInputProtocol!

    var logger: LoggerProtocol?

    private(set) var voteViewModelFactory: VoteViewModelFactoryProtocol
    private(set) var votesDisplayFormatter: NumberFormatter
    private(set) var referendumViewModelFactory: ReferendumViewModelFactoryProtocol

    private(set) var votes: VotesData?
    private(set) var referendum: ReferendumData?

    init(referendumViewModelFactory: ReferendumViewModelFactoryProtocol,
         voteViewModelFactory: VoteViewModelFactoryProtocol,
         votesDisplayFormatter: NumberFormatter) {
        self.referendumViewModelFactory = referendumViewModelFactory
        self.voteViewModelFactory = voteViewModelFactory
        self.votesDisplayFormatter = votesDisplayFormatter
    }

    private func applyLocale() {
        votesDisplayFormatter.locale = localizationManager?.selectedLocale
    }

    private func updateVotesView() {
        if let votes = votes {
            let votesViewModel: String

            if let votes = Decimal(string: votes.value),
               let votesString = votesDisplayFormatter.string(from: votes as NSNumber) {
                votesViewModel = votesString
            } else {
                votesViewModel = ""
            }

            view?.didReceive(votes: votesViewModel)
        }
    }

    private func applyReferendumDetails() {
        if let referendum = referendum {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let viewModel = referendumViewModelFactory.createDetails(from: referendum,
                                                                     locale: locale)

            view?.didReceive(referendum: viewModel)
        }
    }

    private func presentVoting(option: ReferendumVotingCase) {
        guard let referendum = referendum else {
            return
        }

        guard let votes = votes else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        do {
            let viewModel = try voteViewModelFactory.createViewModel(with: referendum,
                                                                     option: option,
                                                                     votes: votes,
                                                                     locale: locale)
            let style = VoteViewStyle.referendumStyle(for: option, locale: locale)
            wireframe.showVotingView(from: view,
                                     with: viewModel,
                                     style: style,
                                     delegate: self)
        } catch VoteViewModelFactoryError.notEnoughVotes {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable.votesZeroErrorMessage(preferredLanguages: languages),
                              title: "",
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            interactor.refreshVotes()
        } catch VoteViewModelFactoryError.noVotesNeeded {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable.votesNotAllowedErrorMessage(preferredLanguages: languages),
                              title: "",
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)
        } catch {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable
                                .votesProjectParametersErrorMessage(preferredLanguages: languages),
                              title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)
        }
    }
}

extension ReferendumDetailsPresenter: ReferendumDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateVotes() {
        wireframe.showVotesHistoryView(from: view)
    }

    func activateClose() {
        wireframe.close(view: view)
    }

    func supportReferendum() {
        presentVoting(option: .support)
    }

    func unsupportReferendum() {
        presentVoting(option: .unsupport)
    }

    func handleElapsedTime() {
        interactor.refreshDetails()

        logger?.debug("Refendum details timer elapsed")
    }
}

extension ReferendumDetailsPresenter: ReferendumDetailsInteractorOutputProtocol {
    func didReceive(votes: VotesData) {
        self.votes = votes
        updateVotesView()
    }

    func didReceiveVotesDataProvider(error: Error) {
        logger?.debug("Did receive votes provider error: \(error)")
    }

    func didReceive(referendum: ReferendumData?) {
        guard let referendum = referendum else {
            wireframe.close(view: view)
            return
        }

        self.referendum = referendum

        applyReferendumDetails()
    }

    func didReceiveReferendumDataProvider(error: Error) {
        logger?.debug("Did receive referendum details provider error: \(error)")
    }

    func didVote(for referendum: ReferendumVote) {
        interactor.refreshVotes()
        interactor.refreshDetails()
    }

    func didReceiveVote(error: Error, for referendum: ReferendumVote) {
        let locale = localizationManager?.selectedLocale

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }

        if let votingError = error as? ReferendumVoteDataError {
            let languages = localizationManager?.preferredLocalizations
            switch votingError {
            case .votesNotEnough:
                wireframe.present(message: R.string.localizable
                                    .votesNotEnoughErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            case .referendumNotFound:
                wireframe.present(message: R.string.localizable
                                    .votesProjectNotFoundErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)

                interactor.refreshDetails()
            case .votingNotAllowed:
                wireframe.present(message: R.string.localizable
                                    .votesNotAllowedErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            case .userNotFound:
                wireframe.present(message: R.string.localizable
                                    .registrationUserNotFoundMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            }
        }
    }
}

extension ReferendumDetailsPresenter: VoteViewDelegate {
    func didVote(on view: VoteView, amount: Decimal) {
        view.presenter?.hide(view: view, animated: true)

        guard case .referendum(let referendumId, let option) = view.model?.target else {
            return
        }

        let votes = amount.rounded(mode: .plain).stringWithPointSeparator
        let referendumVote = ReferendumVote(referendumId: referendumId,
                                            votes: votes,
                                            votingCase: option)

        interactor.vote(for: referendumVote)
    }

    func didCancel(on view: VoteView) {
        logger?.debug("Did cancel voting")
    }
}

extension ReferendumDetailsPresenter: Localizable {
    func applyLocalization() {
        guard let view = view else {
            return
        }

        applyLocale()

        if view.isSetup {
            updateVotesView()
        }
    }
}
