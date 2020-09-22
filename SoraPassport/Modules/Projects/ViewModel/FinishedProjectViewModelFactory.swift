/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

private typealias FinishedVoting = (isSuccessfull: Bool, title: String)

protocol FinishedProjectViewModelFactoryProtocol: DynamicProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: FinishedProjectLayoutMetadata,
                delegate: FinishedProjectViewModelDelegate?,
                locale: Locale) -> FinishedProjectViewModel

    func create(from projectDetails: ProjectDetailsData,
                delegate: ProjectDetailsViewModelDelegate?,
                locale: Locale) -> ProjectDetailsViewModel
}

final class FinishedProjectViewModelFactory {
    private(set) var votesFormatter: LocalizableResource<NumberFormatter>
    private(set) var integerFormatter: LocalizableResource<NumberFormatter>
    private(set) var dateFormatterProvider: DateFormatterProviderProtocol

    weak var delegate: ProjectViewModelFactoryDelegate?

    init(votesFormatter: LocalizableResource<NumberFormatter>,
         integerFormatter: LocalizableResource<NumberFormatter>,
         dateFormatterProvider: DateFormatterProviderProtocol) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
        self.dateFormatterProvider = dateFormatterProvider

        dateFormatterProvider.delegate = self
    }

    private func createFundingProgress(from fundingTarget: String, locale: Locale) -> String {
        guard let fundingDecimal = Decimal(string: fundingTarget) else {
            return ""
        }

        let votesString = votesFormatter.value(for: locale)
            .string(from: fundingDecimal as NSNumber) ?? ""

        return R.string.localizable.projectVotesTemplate(votesString,
                                                         preferredLanguages: locale.rLanguages)
    }

    private func createCompletionDetails(from fundingDeadline: Int64, locale: Locale) -> String {
        let fundingDeadline = Date(timeIntervalSince1970: TimeInterval(fundingDeadline))

        if fundingDeadline.compare(Date()) != .orderedDescending {
            let dateFormatter = dateFormatterProvider.dateFormatter.value(for: locale)
            return R.string.localizable.projectEndedTemplate(dateFormatter.string(from: fundingDeadline),
                                                             preferredLanguages: locale.rLanguages)
        } else {
            return ""
        }
    }

    private func createVotingDetails(from status: ProjectDataStatus, locale: Locale) -> FinishedVoting {
        let isSuccessfull = status != .failed
        let title = isSuccessfull ?
            R.string.localizable.projectSuccessfulVoting(preferredLanguages: locale.rLanguages) :
            R.string.localizable.projectUnsuccessfulVoting(preferredLanguages: locale.rLanguages)

        return FinishedVoting(isSuccessfull: isSuccessfull,
                              title: title)
    }

    private func createRewardDetails(from votes: String,
                                     status: ProjectDataStatus,
                                     locale: Locale) -> String? {
        guard let votes = Decimal(string: votes), votes > 0 else {
            return nil
        }

        guard let votesString = votesFormatter.value(for: locale).string(from: votes as NSNumber) else {
            return nil
        }

        return R.string.localizable.projectSpentFormat(votesString,
                                                       preferredLanguages: locale.rLanguages)
    }

    private func createContent(from project: ProjectData, locale: Locale) -> FinishedProjectContent {
        return FinishedProjectContent {
            $0.title = project.name
            $0.details = project.description ?? ""
            $0.isVoted = project.isVoted

            $0.fundingProgressDetails = createFundingProgress(from: project.fundingTarget,
                                                              locale: locale)

            $0.completionTimeDetails = createCompletionDetails(from: project.statusUpdateTime,
                                                               locale: locale)

            let votingDetails = createVotingDetails(from: project.status,
                                                    locale: locale)
            $0.isSuccessfull = votingDetails.isSuccessfull
            $0.votingTitle = votingDetails.title

            $0.isFavorite = project.favorite

            if project.favoriteCount > 0,
                let favoriteString = integerFormatter.value(for: locale)
                    .string(from: NSNumber(value: project.favoriteCount)) {
                $0.favoriteDetails = favoriteString
            }

            $0.rewardDetails = createRewardDetails(from: project.votes,
                                                   status: project.status,
                                                   locale: locale)
        }
    }
}

extension FinishedProjectViewModelFactory: FinishedProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: FinishedProjectLayoutMetadata,
                delegate: FinishedProjectViewModelDelegate?,
                locale: Locale) -> FinishedProjectViewModel {

        let content = createContent(from: project, locale: locale)
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
                delegate: ProjectDetailsViewModelDelegate?,
                locale: Locale) -> ProjectDetailsViewModel {
        let viewModel = ProjectDetailsViewModel()

        viewModel.title = projectDetails.title
        viewModel.isFavorite = projectDetails.favorite

        viewModel.fundingDetails = createFundingProgress(from: projectDetails.fundingTarget,
                                                         locale: locale)

        viewModel.remainedTimeDetails = createCompletionDetails(from: projectDetails.statusUpdateTime,
                                                                locale: locale)

        let votingDetails = createVotingDetails(from: projectDetails.status, locale: locale)
        viewModel.status = .finished(successfull: votingDetails.isSuccessfull)
        viewModel.votingTitle = votingDetails.title

        viewModel.isFavorite = projectDetails.favorite
        viewModel.isVoted = projectDetails.isVoted

        viewModel.rewardDetails = createRewardDetails(from: projectDetails.votes,
                                                      status: projectDetails.status,
                                                      locale: locale)

        let votedFriendsString = R.string.localizable
            .votedFriends(voted: Int(projectDetails.votedFriendsCount),
                          preferredLanguages: locale.rLanguages)

        let favoritesString = R.string.localizable
            .favoriteUsers(favorite: Int(projectDetails.favoriteCount),
                           preferredLanguages: locale.rLanguages)

        if projectDetails.votedFriendsCount > 0, projectDetails.favoriteCount > 0 {
            viewModel.statisticsDetails = R.string.localizable
                .projectDetailsFavoriteVotedCount(votedFriendsString, favoritesString,
                                                  preferredLanguages: locale.rLanguages)
        } else if projectDetails.votedFriendsCount > 0 {
            viewModel.statisticsDetails = votedFriendsString
        } else if projectDetails.favoriteCount > 0 {
            viewModel.statisticsDetails = favoritesString
        }

        if let discussionLink = projectDetails.discussionLink {
            viewModel.discussionDetails = R.string.localizable
                .projectDiscussionTemplate(discussionLink.title,
                                           preferredLanguages: locale.rLanguages)
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
