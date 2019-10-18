/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol VoteViewModelFactoryProtocol {
    func createViewModel(with project: ProjectData,
                         votes: VotesData) throws -> VoteViewModelProtocol

    func createViewModel(with projectDetails: ProjectDetailsData,
                         votes: VotesData) throws -> VoteViewModelProtocol
}

enum VoteViewModelFactoryError: Error {
    case notEnoughVotes
    case currentOrTargetValueMissing
    case noVotesNeeded
}

final class VoteViewModelFactory {
    private(set) var amountFormatter: NumberFormatter

    init(amountFormatter: NumberFormatter) {
        self.amountFormatter = amountFormatter
    }

    private func createViewModel(for projectId: String,
                                 votes: VotesData,
                                 fundingCurrent: String,
                                 fundingTarget: String) throws -> VoteViewModelProtocol {
        let minimumVotes: Decimal = 1.0
        var availableVotes: Decimal = 0.0

        if let votes = Decimal(string: votes.value) {
            availableVotes = votes.rounded(mode: .down)
        }

        guard availableVotes >= minimumVotes else {
            throw VoteViewModelFactoryError.notEnoughVotes
        }

        guard
            let fundingCurrent = Decimal(string: fundingCurrent),
            let fundingTarget = Decimal(string: fundingTarget) else {
                throw VoteViewModelFactoryError.currentOrTargetValueMissing
        }

        let neededVotes = fundingTarget - fundingCurrent

        guard neededVotes >= minimumVotes else {
            throw VoteViewModelFactoryError.noVotesNeeded
        }

        let maximumVotes: Decimal
        let maximumBoundPolicy: VoteViewModel.BoundBreakPolicy

        if availableVotes < neededVotes {
            maximumVotes = availableVotes
            maximumBoundPolicy = .notify
        } else {
            maximumVotes = neededVotes
            maximumBoundPolicy = .adjust
        }

        let viewModel = VoteViewModel(projectId: projectId,
                                      amount: minimumVotes,
                                      minimumVoteAmount: minimumVotes,
                                      maximumVoteAmount: maximumVotes)

        viewModel.rightBoundBreakPolicy = maximumBoundPolicy
        viewModel.amountFormatter = amountFormatter
        viewModel.errorDisplayMapping = createErrorDisplayMapping(for: maximumVotes)

        return viewModel
    }

    private func createErrorDisplayMapping(for maximumVotes: Decimal) -> (VoteViewModelError) -> String {
        let formattedVotes = amountFormatter.string(from: maximumVotes as NSNumber)
        return { error in
            switch error {
            case .emptyAmount:
                return R.string.localizable.voteTooSmallErrorMessage()
            case .tooSmallAmount:
                return R.string.localizable.voteTooSmallErrorMessage()
            case .tooBigAmount:
                return R.string.localizable.voteNotEnoughErrorMessage()
            case .adjustedMax:
                if let votes = formattedVotes {
                    return R.string.localizable.voteProjectMaxMessage(votes)
                } else {
                    return ""
                }
            }
        }
    }
}

extension VoteViewModelFactory: VoteViewModelFactoryProtocol {
    func createViewModel(with project: ProjectData,
                         votes: VotesData) throws -> VoteViewModelProtocol {
        return try createViewModel(for: project.identifier,
                                   votes: votes,
                                   fundingCurrent: project.fundingCurrent,
                                   fundingTarget: project.fundingTarget)
    }

    func createViewModel(with projectDetails: ProjectDetailsData,
                         votes: VotesData) throws -> VoteViewModelProtocol {
        return try createViewModel(for: projectDetails.identifier,
                                   votes: votes,
                                   fundingCurrent: projectDetails.fundingCurrent,
                                   fundingTarget: projectDetails.fundingTarget)
    }
}
