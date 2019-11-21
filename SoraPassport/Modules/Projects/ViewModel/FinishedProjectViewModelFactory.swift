/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

private typealias FinishedVoting = (isSuccessfull: Bool, title: String)

protocol FinishedProjectViewModelFactoryProtocol: DynamicProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: FinishedProjectLayoutMetadata,
                delegate: FinishedProjectViewModelDelegate?) -> FinishedProjectViewModel

    func create(from projectDetails: ProjectDetailsData,
                delegate: ProjectDetailsViewModelDelegate?) -> ProjectDetailsViewModel
}

final class FinishedProjectViewModelFactory {
    private(set) var votesFormatter: NumberFormatter
    private(set) var integerFormatter: NumberFormatter
    private(set) var dateFormatterProvider: DateFormatterProviderProtocol

    weak var delegate: ProjectViewModelFactoryDelegate?

    init(votesFormatter: NumberFormatter,
         integerFormatter: NumberFormatter,
         dateFormatterProvider: DateFormatterProviderProtocol) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
        self.dateFormatterProvider = dateFormatterProvider

        dateFormatterProvider.delegate = self
    }

    private func createFundingProgress(from fundingTarget: String) -> String {
        guard let fundingDecimal = Decimal(string: fundingTarget) else {
            return ""
        }

        let votesString = votesFormatter.string(from: fundingDecimal as NSNumber) ?? ""

        return R.string.localizable.projectFinishedVotes(votesString)
    }

    private func createCompletionDetails(from fundingDeadline: Int64) -> String {
        let fundingDeadline = Date(timeIntervalSince1970: TimeInterval(fundingDeadline))

        if fundingDeadline.compare(Date()) != .orderedDescending {
            return R.string.localizable
                .projectFinishedAt(dateFormatterProvider.dateFormatter.string(from: fundingDeadline))
        } else {
            return ""
        }
    }

    private func createVotingDetails(from status: ProjectDataStatus) -> FinishedVoting {
        let isSuccessfull = status != .failed
        let title = isSuccessfull ? R.string.localizable.projectFinishedSuccessfullTitle() :
            R.string.localizable.projectFinishedUnsuccessfullTitle()

        return FinishedVoting(isSuccessfull: isSuccessfull,
                              title: title)
    }

    private func createRewardDetails(from votes: String,
                                     status: ProjectDataStatus) -> String? {
        guard let votes = Decimal(string: votes), votes > 0 else {
            return nil
        }

        guard let votesString = votesFormatter.string(from: votes as NSNumber) else {
            return nil
        }

        return R.string.localizable.projectFinishedSpentVotes(votesString)
    }

    private func createContent(from project: ProjectData) -> FinishedProjectContent {
        return FinishedProjectContent {
            $0.title = project.name
            $0.details = project.description ?? ""
            $0.isVoted = project.isVoted

            $0.fundingProgressDetails = createFundingProgress(from: project.fundingTarget)

            $0.completionTimeDetails = createCompletionDetails(from: project.statusUpdateTime)

            let votingDetails = createVotingDetails(from: project.status)
            $0.isSuccessfull = votingDetails.isSuccessfull
            $0.votingTitle = votingDetails.title

            $0.isFavorite = project.favorite

            if project.favoriteCount > 0,
                let favoriteString = integerFormatter.string(from: NSNumber(value: project.favoriteCount)) {
                $0.favoriteDetails = favoriteString
            }

            $0.rewardDetails = createRewardDetails(from: project.votes,
                                                   status: project.status)
        }
    }
}

extension FinishedProjectViewModelFactory: FinishedProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: FinishedProjectLayoutMetadata,
                delegate: FinishedProjectViewModelDelegate?) -> FinishedProjectViewModel {

        let content = createContent(from: project)
        let layout = createLayout(from: content,
                                  layoutMetadata: layoutMetadata)

        let viewModel = FinishedProjectViewModel(identifier: project.identifier,
                                                 content: content,
                                                 layout: layout,
                                                 imageViewModel: nil)

        if let imageLink = project.imageLink {
            viewModel.imageViewModel = ImageViewModel(url: imageLink)
            viewModel.imageViewModel?.cornerRadius = layoutMetadata.cornerRadius
            viewModel.imageViewModel?.targetSize = layout.imageSize
        }

        viewModel.delegate = delegate

        return viewModel
    }

    func create(from projectDetails: ProjectDetailsData,
                delegate: ProjectDetailsViewModelDelegate?) -> ProjectDetailsViewModel {
        let viewModel = ProjectDetailsViewModel()

        viewModel.title = projectDetails.title
        viewModel.isFavorite = projectDetails.favorite

        viewModel.fundingDetails = createFundingProgress(from: projectDetails.fundingTarget)

        viewModel.remainedTimeDetails = createCompletionDetails(from: projectDetails.statusUpdateTime)

        let votingDetails = createVotingDetails(from: projectDetails.status)
        viewModel.status = .finished(successfull: votingDetails.isSuccessfull)
        viewModel.votingTitle = votingDetails.title

        viewModel.isFavorite = projectDetails.favorite
        viewModel.isVoted = projectDetails.isVoted

        viewModel.rewardDetails = createRewardDetails(from: projectDetails.votes,
                                                      status: projectDetails.status)

        let votedFriendsString = R.string.localizable.votedFriends(voted: Int(projectDetails.votedFriendsCount))
        let favoritesString = R.string.localizable.favoriteUsers(favorite: Int(projectDetails.favoriteCount))

        if !votedFriendsString.isEmpty, !favoritesString.isEmpty {
            viewModel.statisticsDetails = R.string.localizable
                .projectDetailsFavoriteVotedCount(votedFriendsString, favoritesString)
        } else if !votedFriendsString.isEmpty {
            viewModel.statisticsDetails = votedFriendsString
        } else if !favoritesString.isEmpty {
            viewModel.statisticsDetails = favoritesString
        }

        if let discussionLink = projectDetails.discussionLink {
            viewModel.discussionDetails = R.string.localizable
                .projectDetailsDiscussFormat(discussionLink.title)
        }

        viewModel.details = projectDetails.details ?? projectDetails.annotation

        viewModel.website = projectDetails.link?.absoluteString ?? ""
        viewModel.email = projectDetails.email ?? ""

        if let mainImageLink = projectDetails.imageLink {
            viewModel.mainImageViewModel = ImageViewModel(url: mainImageLink)
        }

        if let gallery = projectDetails.gallery {
            viewModel.galleryImageViewModels = gallery.map { GalleryViewModel.from(media: $0) }
        }

        viewModel.delegate = delegate

        return viewModel
    }
}

extension FinishedProjectViewModelFactory: DateFormatterProviderDelegate {
    func providerDidChangeDateFormatter(_ provider: DateFormatterProviderProtocol) {
        delegate?.projectFactoryDidChange(self)
    }
}
