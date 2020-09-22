import Foundation
import SoraFoundation

protocol OpenProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: OpenProjectLayoutMetadata,
                delegate: OpenProjectViewModelDelegate?,
                locale: Locale) -> OpenProjectViewModel

    func create(from projectDetails: ProjectDetailsData,
                delegate: ProjectDetailsViewModelDelegate?,
                locale: Locale) -> ProjectDetailsViewModel
}

final class OpenProjectViewModelFactory {
    private(set) var votesFormatter: LocalizableResource<NumberFormatter>
    private(set) var integerFormatter: LocalizableResource<NumberFormatter>

    init(votesFormatter: LocalizableResource<NumberFormatter>, integerFormatter: LocalizableResource<NumberFormatter>) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
    }

    private func convertRemained(timestamp: Int64, locale: Locale) -> String {
        let preferredLanguages = locale.rLanguages

        if timestamp < 60 {
            return R.string.localizable.projectDateSecondPlurals(value: Int(timestamp),
                                                                 preferredLanguages: preferredLanguages)
        }

        if timestamp < 3600 {
            return R.string.localizable.projectDateMinutePlurals(value: Int(timestamp / 60),
                                                                 preferredLanguages: preferredLanguages)
        }

        if timestamp < 24 * 3600 {
            return R.string.localizable.projectDateHourPlurals(value: Int(timestamp / 3600),
                                                               preferredLanguages: preferredLanguages)
        }

        return R.string.localizable.projectDateDayPlurals(value: Int(timestamp / (24 * 3600)),
                                                          preferredLanguages: preferredLanguages)
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

    private func createFundingProgressDetails(from progress: Float, fundingTarget: String, locale: Locale) -> String {
        let fundingTarget = Decimal(string: fundingTarget)

        let progressDescription = String(Int(progress * 100.0))
        var targetDescription = ""

        if let fundingTarget = fundingTarget {
            targetDescription = votesFormatter.value(for: locale).string(from: fundingTarget as NSNumber) ?? ""
        }

        return R.string.localizable.projectFoundedTemplate(progressDescription,
                                                    targetDescription,
                                                    preferredLanguages: locale.rLanguages)
    }

    private func createVoteTitle(from votes: String, locale: Locale) -> String {
        if let votedAmount = Decimal(string: votes), votedAmount > 0.0 {
            return votesFormatter.value(for: locale).string(from: votedAmount as NSNumber) ?? votes
        } else {
            return R.string.localizable.projectNotVotedTitle(preferredLanguages: locale.rLanguages)
        }
    }

    private func createRemainedDeadlineDescrition(from fundingDeadline: Int64, locale: Locale) -> String {
        let timestampLeft = fundingDeadline - Int64(Date().timeIntervalSince1970)
        return timestampLeft > 0 ? convertRemained(timestamp: timestampLeft, locale: locale) : ""
    }

    private func createContent(from project: ProjectData, locale: Locale) -> OpenProjectContent {
        return OpenProjectContent {
            $0.title = project.name
            $0.details = project.description ?? ""
            $0.isFavorite = project.favorite
            $0.isNew = project.unwatched

            let progress = createFundingProgress(from: project.fundingCurrent,
                                                 fundingTarget: project.fundingTarget)
            $0.fundingProgressValue = progress

            $0.fundingProgressDetails = createFundingProgressDetails(from: progress,
                                                                     fundingTarget: project.fundingTarget,
                                                                     locale: locale)

            $0.remainedTimeDetails = createRemainedDeadlineDescrition(from: project.fundingDeadline,
                                                                      locale: locale)

            $0.voteTitle = createVoteTitle(from: project.votes, locale: locale)

            $0.isVoted = project.isVoted

            if project.votedFriendsCount > 0 {
                $0.votedFriendsDetails = R.string.localizable
                    .votedFriends(voted: Int(project.votedFriendsCount),
                                  preferredLanguages: locale.rLanguages)
            }

            if project.favoriteCount > 0,
                let favoritesString = integerFormatter.value(for: locale)
                    .string(from: NSNumber(value: project.favoriteCount)) {
                $0.favoriteDetails = favoritesString
            }
        }
    }
}

extension OpenProjectViewModelFactory: OpenProjectViewModelFactoryProtocol {
    func create(from project: ProjectData,
                layoutMetadata: OpenProjectLayoutMetadata,
                delegate: OpenProjectViewModelDelegate?,
                locale: Locale) -> OpenProjectViewModel {

        let content = createContent(from: project, locale: locale)

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
                delegate: ProjectDetailsViewModelDelegate?,
                locale: Locale) -> ProjectDetailsViewModel {
        let viewModel = ProjectDetailsViewModel()
        viewModel.status = .open

        viewModel.title = projectDetails.title
        viewModel.isFavorite = projectDetails.favorite
        viewModel.isVoted = projectDetails.isVoted

        viewModel.fundingProgressValue = createFundingProgress(from: projectDetails.fundingCurrent,
                                                               fundingTarget: projectDetails.fundingTarget)

        viewModel.fundingDetails = createFundingProgressDetails(from: viewModel.fundingProgressValue,
                                                                fundingTarget: projectDetails.fundingTarget,
                                                                locale: locale)

        viewModel.remainedTimeDetails = createRemainedDeadlineDescrition(from: projectDetails.fundingDeadline,
                                                                         locale: locale)

        viewModel.votingTitle = createVoteTitle(from: projectDetails.votes,
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
