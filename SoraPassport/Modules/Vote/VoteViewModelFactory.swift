/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
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
                                 fundingTarget: String) throws
        -> VoteViewModelProtocol {
        let minimumVotes: Float = 1.0
        var availableVotes: Float = 0.0

        if let votes = Double(votes.value) {
            availableVotes = Float(floor(votes))
        }

        guard availableVotes >= minimumVotes else {
            throw VoteViewModelFactoryError.notEnoughVotes
        }

        guard let fundingCurrent = Decimal(string: fundingCurrent),
            let fundingTarget = Decimal(string: fundingTarget) else {
                throw VoteViewModelFactoryError.currentOrTargetValueMissing
        }

        let neededVotes = Float(ceil(((fundingTarget - fundingCurrent) as NSDecimalNumber).doubleValue))

        guard neededVotes >= minimumVotes else {
            throw VoteViewModelFactoryError.noVotesNeeded
        }

        let maximumValue = min(availableVotes, neededVotes)

        let errorMapping: [VoteViewModelError: String] = [
            .emptyAmount: R.string.localizable.voteTooSmallErrorMessage(),
            .tooSmallAmount: R.string.localizable.voteTooSmallErrorMessage(),
            .tooBigAmount: R.string.localizable.voteTooBigErrorMessage()
        ]

        let viewModel = VoteViewModel(projectId: projectId,
                                      amount: minimumVotes,
                                      minimumVoteAmount: minimumVotes,
                                      maximumVoteAmount: maximumValue)
        viewModel.amountFormatter = amountFormatter
        viewModel.errorDisplayMapping = errorMapping

        return viewModel
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
