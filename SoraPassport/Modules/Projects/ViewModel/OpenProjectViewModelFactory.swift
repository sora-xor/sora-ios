/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol OpenProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: OpenProjectLayoutMetadata,
                delegate: OpenProjectViewModelDelegate?) -> OpenProjectViewModel

    func create(from projectDetails: ProjectDetailsData,
                delegate: ProjectDetailsViewModelDelegate?) -> ProjectDetailsViewModel
}

final class OpenProjectViewModelFactory {
    private(set) var votesFormatter: NumberFormatter
    private(set) var integerFormatter: NumberFormatter

    init(votesFormatter: NumberFormatter, integerFormatter: NumberFormatter) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
    }

    private func convertRemained(timestamp: Int64) -> String {
        if timestamp < 60 {
            return R.string.localizable.remainedSeconds(value: Int(timestamp))
        }

        if timestamp < 3600 {
            return R.string.localizable.remainedMinutes(value: Int(timestamp / 60))
        }

        if timestamp < 24 * 3600 {
            return R.string.localizable.remainedHours(value: Int(timestamp / 3600))
        }

        return R.string.localizable.remainedDays(value: Int(timestamp / (24 * 3600)))
    }

    private func createFundingProgress(from fundingCurrent: String, fundingTarget: String) -> Float {
        var progress: Float = 1.0

        let fundingCurrent = Decimal(string: fundingCurrent)
        let fundingTarget = Decimal(string: fundingTarget)

        if let fundingCurrent = fundingCurrent, let fundingTarget = fundingTarget, fundingTarget > 0 {
            progress = Float(truncating: (fundingCurrent / fundingTarget) as NSNumber)
        }

        return progress
    }

    private func createFundingProgressDetails(from progress: Float, fundingTarget: String) -> String {
        let fundingTarget = Decimal(string: fundingTarget)

        let progressDescription = String(Int(progress * 100.0))
        var targetDescription = ""

        if let fundingTarget = fundingTarget {
            targetDescription = votesFormatter.string(from: fundingTarget as NSNumber) ?? ""
        }

        return R.string.localizable.projectFundedOf(progressDescription,
                                                    targetDescription)
    }

    private func createVoteTitle(from votes: String) -> String {
        if let votedAmount = Decimal(string: votes), votedAmount > 0.0 {
            return votesFormatter.string(from: votedAmount as NSNumber) ?? votes
        } else {
            return R.string.localizable.projectNotVotedTitle()
        }
    }

    private func createRemainedDeadlineDescrition(from fundingDeadline: Int64) -> String {
        let timestampLeft = fundingDeadline - Int64(Date().timeIntervalSince1970)
        return timestampLeft > 0 ? convertRemained(timestamp: timestampLeft) : ""
    }

    private func createContent(from project: ProjectData) -> OpenProjectContent {
        return OpenProjectContent {
            $0.title = project.name
            $0.details = project.description ?? ""
            $0.isFavorite = project.favorite
            $0.isNew = project.unwatched

            let progress = createFundingProgress(from: project.fundingCurrent,
                                                 fundingTarget: project.fundingTarget)
            $0.fundingProgressValue = progress

            $0.fundingProgressDetails = createFundingProgressDetails(from: progress,
                                                                     fundingTarget: project.fundingTarget)

            $0.remainedTimeDetails = createRemainedDeadlineDescrition(from: project.fundingDeadline)

            $0.voteTitle = createVoteTitle(from: project.votes)

            $0.isVoted = project.isVoted

            if project.votedFriendsCount > 0 {
                $0.votedFriendsDetails = R.string.localizable
                    .votedFriends(voted: Int(project.votedFriendsCount))
            }

            if project.favoriteCount > 0,
                let favoritesString = integerFormatter.string(from: NSNumber(value: project.favoriteCount)) {
                $0.favoriteDetails = favoritesString
            }
        }
    }
}

extension OpenProjectViewModelFactory: OpenProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: OpenProjectLayoutMetadata,
                delegate: OpenProjectViewModelDelegate?) -> OpenProjectViewModel {

        let content = createContent(from: project)

        let layout = createLayout(from: content,
                                  layoutMetadata: layoutMetadata)

        let viewModel = OpenProjectViewModel(identifier: project.identifier,
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
        viewModel.status = .open

        viewModel.title = projectDetails.title
        viewModel.isFavorite = projectDetails.favorite
        viewModel.isVoted = projectDetails.isVoted

        viewModel.fundingProgressValue = createFundingProgress(from: projectDetails.fundingCurrent,
                                                               fundingTarget: projectDetails.fundingTarget)

        viewModel.fundingDetails = createFundingProgressDetails(from: viewModel.fundingProgressValue,
                                                                        fundingTarget: projectDetails.fundingTarget)

        viewModel.remainedTimeDetails = createRemainedDeadlineDescrition(from: projectDetails.fundingDeadline)

        viewModel.votingTitle = createVoteTitle(from: projectDetails.votes)

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
