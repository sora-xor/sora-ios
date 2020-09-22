import Foundation
import SoraFoundation

protocol VoteViewModelFactoryProtocol {
    func createViewModel(with project: ProjectData,
                         votes: VotesData,
                         locale: Locale) throws -> VoteViewModelProtocol

    func createViewModel(with projectDetails: ProjectDetailsData,
                         votes: VotesData,
                         locale: Locale) throws -> VoteViewModelProtocol

    func createViewModel(with referendum: ReferendumData,
                         option: ReferendumVotingCase,
                         votes: VotesData,
                         locale: Locale) throws -> VoteViewModelProtocol
}

enum VoteViewModelFactoryError: Error {
    case notEnoughVotes
    case currentOrTargetValueMissing
    case noVotesNeeded
}

final class VoteViewModelFactory {
    let amountFormatter: LocalizableResource<NumberFormatter>

    init(amountFormatter: LocalizableResource<NumberFormatter>) {
        self.amountFormatter = amountFormatter
    }

    private func createViewModel(for target: VotingTarget,
                                 votes: VotesData,
                                 fundingCurrent: String,
                                 fundingTarget: String,
                                 locale: Locale) throws -> VoteViewModelProtocol {
        let minimumVotes: Decimal = 1.0

        guard
            let fundingCurrent = Decimal(string: fundingCurrent),
            let fundingTarget = Decimal(string: fundingTarget) else {
                throw VoteViewModelFactoryError.currentOrTargetValueMissing
        }

        let neededVotes = fundingTarget - fundingCurrent

        guard neededVotes >= minimumVotes else {
            throw VoteViewModelFactoryError.noVotesNeeded
        }

        return try createViewModel(for: target,
                                   votes: votes,
                                   neededVotes: neededVotes,
                                   locale: locale)
    }

    private func createViewModel(for target: VotingTarget,
                                 votes: VotesData,
                                 neededVotes: Decimal,
                                 locale: Locale) throws -> VoteViewModelProtocol {
        let minimumVotes: Decimal = 1.0
        var availableVotes: Decimal = 0.0

        if let votes = Decimal(string: votes.value) {
            availableVotes = votes.rounded(mode: .down)
        }

        guard availableVotes >= minimumVotes else {
            throw VoteViewModelFactoryError.notEnoughVotes
        }

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

        let viewModel = VoteViewModel(target: target,
                                      amount: minimumVotes,
                                      minimumVoteAmount: minimumVotes,
                                      maximumVoteAmount: maximumVotes,
                                      locale: locale)

        viewModel.rightBoundBreakPolicy = maximumBoundPolicy
        viewModel.amountFormatter = amountFormatter.value(for: locale)
        viewModel.errorDisplayMapping = createErrorDisplayMapping(for: maximumVotes, locale: locale)

        return viewModel
    }

    private func createErrorDisplayMapping(for maximumVotes: Decimal,
                                           locale: Locale) -> (VoteViewModelError) -> String {
        let formattedVotes = amountFormatter.value(for: locale).string(from: maximumVotes as NSNumber)
        return { error in
            switch error {
            case .emptyAmount:
                return R.string.localizable
                    .projectYouCanVoteAtLeast1Point(preferredLanguages: locale.rLanguages)
            case .tooSmallAmount:
                return R.string.localizable
                    .projectYouCanVoteAtLeast1Point(preferredLanguages: locale.rLanguages)
            case .tooBigAmount:
                return R.string.localizable
                    .projectUserHaveNotEnoughVotesMessage(preferredLanguages: locale.rLanguages)
            case .adjustedMax:
                if let votes = formattedVotes {
                    return R.string.localizable
                        .projectRequiresVotesFormat(votes, preferredLanguages: locale.rLanguages)
                } else {
                    return ""
                }
            }
        }
    }
}

extension VoteViewModelFactory: VoteViewModelFactoryProtocol {
    func createViewModel(with project: ProjectData,
                         votes: VotesData,
                         locale: Locale) throws -> VoteViewModelProtocol {
        return try createViewModel(for: .project(identifier: project.identifier),
                                   votes: votes,
                                   fundingCurrent: project.fundingCurrent,
                                   fundingTarget: project.fundingTarget,
                                   locale: locale)
    }

    func createViewModel(with projectDetails: ProjectDetailsData,
                         votes: VotesData,
                         locale: Locale) throws -> VoteViewModelProtocol {
        return try createViewModel(for: .project(identifier: projectDetails.identifier),
                                   votes: votes,
                                   fundingCurrent: projectDetails.fundingCurrent,
                                   fundingTarget: projectDetails.fundingTarget,
                                   locale: locale)
    }

    func createViewModel(with referendum: ReferendumData,
                         option: ReferendumVotingCase,
                         votes: VotesData,
                         locale: Locale) throws -> VoteViewModelProtocol {
        guard let neededVotes = Decimal(string: votes.value) else {
            throw VoteViewModelFactoryError.notEnoughVotes
        }

        let target: VotingTarget = .referendum(identifier: referendum.identifier, option: option)
        return try createViewModel(for: target,
                                   votes: votes,
                                   neededVotes: neededVotes,
                                   locale: locale)
    }
}
