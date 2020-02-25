/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension ActivityFeedViewModelFactory {
    func transform(event: ActivityOneOfEventData,
                   from activity: ActivityData,
                   metadataContainer: ActivityFeedLayoutMetadataContainer,
                   locale: Locale)
        -> SectionedActivityFeedItemViewModel? {

            switch event {
            case .friendRegistered(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .votingRightsCredited(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .userRankChanged(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .projectFunded(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .projectClosed(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .projectCreated(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .xorTransfered(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .xorRewardCreditedFromProject(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            case .userHasVoted(let concreteEvent):
                return transform(event: concreteEvent, from: activity, metadataContainer: metadataContainer,
                                 locale: locale)
            default:
                return nil
            }
    }

    private func transformSection(timestamp: Int64, locale: Locale) -> String {
        return sectionFormatterProvider.dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private func transformActivity(timestamp: Int64, locale: Locale) -> String {
        return timestampDateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private func transform(event: FriendRegisteredEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityUser()
                $0.type = R.string.localizable.activityUserRegisteredType(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                if let userInfo = activity.users?[event.userId] {
                    $0.title = "\(userInfo.firstName) \(userInfo.lastName)"
                } else {
                    $0.title = R.string.localizable.activityUser(preferredLanguages: locale.rLanguages)
                }

                $0.details = R.string.localizable
                    .activityUserRegisteredDescription(preferredLanguages: locale.rLanguages)
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: VotingRightsCreditedEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedAmountItemContent {
                $0.icon = R.image.iconActivityVote()
                $0.type = R.string.localizable
                    .activityVotingRightsCreditedTypeTemplate(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                let votingRights = Decimal(string: event.votingRights) ?? 0
                let votesString = votesNumberFormatter.value(for: locale)
                    .string(from: (votingRights as NSNumber)) ?? ""
                $0.details = R.string.localizable
                    .activityVotingRightsTitleTemplate(preferredLanguages: locale.rLanguages)

                $0.amountStateIcon = R.image.increaseIcon()
                $0.amountText = votesString
                $0.amountSymbolIcon = R.image.activityVotesIcon()
            }

            let layout = createLayout(for: content, metadata: metadataContainer.amountLayoutMetadata)

            let viewModel = ActivityFeedAmountItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .amount(concreteViewModel: viewModel))
    }

    private func transform(event: UserRankChangedEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityRank()
                $0.type = R.string.localizable
                    .activityUserRankChangedTypeTemplate(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                if let rankString = integerFormatter.value(for: locale)
                    .string(from: NSNumber(value: event.rank)),
                    let totalRankString = integerFormatter.value(for: locale)
                        .string(from: NSNumber(value: event.totalRank)) {
                    $0.details = R.string.localizable
                        .activityUserRankChangedTitleTemplate(rankString,
                                                              totalRankString,
                                                              preferredLanguages: locale.rLanguages)
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: ProjectFundedEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable
                    .activityProjectFundedTypeTemplate(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                if let project = activity.projects?[event.projectId] {
                    $0.title = project.name
                } else {
                    $0.title = R.string.localizable
                        .activityProject(preferredLanguages: locale.rLanguages)
                }

                $0.details = R.string.localizable
                    .activityProjectFundedDescriptionTemplate(preferredLanguages: locale.rLanguages)
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: ProjectClosedEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable
                    .activityProjectClosedTypeTemplate(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                if let project = activity.projects?[event.projectId] {
                    $0.title = project.name
                } else {
                    $0.title = R.string.localizable.activityProject(preferredLanguages: locale.rLanguages)
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: ProjectCreatedEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable
                    .activityProjectCreatedTypeTemplate(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)
                $0.title = event.name
                $0.details = event.description
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: XORTransferedEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedAmountItemContent {
                $0.icon = R.image.iconXor()
                $0.type = R.string.localizable
                    .activityEventXorTransferedType(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                let xor = Decimal(string: event.amount) ?? 0
                let amountString = amountFormatter.value(for: locale).string(from: (xor as NSNumber)) ?? ""

                if let userInfo = activity.users?[event.source] {
                    $0.details = "\(userInfo.firstName) \(userInfo.lastName)"
                } else {
                    $0.details = R.string.localizable
                        .activityUser(preferredLanguages: locale.rLanguages)
                }

                $0.amountStateIcon = R.image.increaseIcon()
                $0.amountText = String.xor + amountString
            }

            let layout = createLayout(for: content, metadata: metadataContainer.amountLayoutMetadata)

            let viewModel = ActivityFeedAmountItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .amount(concreteViewModel: viewModel))
    }

    private func transform(event: XORRewardCreditedFromProjectEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedAmountItemContent {
                $0.icon = R.image.iconXor()
                $0.type = R.string.localizable
                    .activityXorRewardCreditedFromProjectTypeTemplate(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                let reward = Decimal(string: event.reward) ?? 0
                let rewardString = amountFormatter.value(for: locale).string(from: reward as NSNumber) ?? ""

                if let project = activity.projects?[event.projectId] {
                    $0.details = project.name
                } else {
                    $0.details = R.string.localizable
                        .activityProject(preferredLanguages: locale.rLanguages)
                }

                $0.amountStateIcon = R.image.increaseIcon()
                $0.amountText = String.xor + rewardString
            }

            let layout = createLayout(for: content, metadata: metadataContainer.amountLayoutMetadata)

            let viewModel = ActivityFeedAmountItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .amount(concreteViewModel: viewModel))
    }

    private func transform(event: UserHasVotedEventData,
                           from activity: ActivityData,
                           metadataContainer: ActivityFeedLayoutMetadataContainer,
                           locale: Locale)
        -> SectionedActivityFeedItemViewModel {

            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityVote()
                $0.type = R.string.localizable
                    .activityVotedFriendAddedTypeTemplate(preferredLanguages: locale.rLanguages)
                $0.timestamp = transformActivity(timestamp: event.issuedAt, locale: locale)

                let givenVotes = Decimal(string: event.givenVotes) ?? 0
                let givenVotesString = votesNumberFormatter.value(for: locale)
                    .string(from: givenVotes as NSNumber) ?? ""

                let fullName: String
                let firstName: String
                let projectName: String

                if let user = activity.users?[event.userId] {
                    fullName = "\(user.firstName) \(user.lastName)"
                    firstName = user.firstName
                } else {
                    fullName = R.string.localizable.activityUser(preferredLanguages: locale.rLanguages)
                    firstName = R.string.localizable.activityUser(preferredLanguages: locale.rLanguages)
                }

                if let project = activity.projects?[event.projectId] {
                    projectName = project.name
                } else {
                    projectName = R.string.localizable.activityProject(preferredLanguages: locale.rLanguages)
                }

                $0.title = fullName
                $0.details = R.string.localizable
                    .activityVotedFriendAddedDescriptionTemplate(firstName,
                                                                 givenVotesString,
                                                                 projectName,
                                                                 preferredLanguages: locale.rLanguages)
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            let sectionTitle = transformSection(timestamp: event.issuedAt, locale: locale)
            return SectionedActivityFeedItemViewModel(sectionTitle: sectionTitle,
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }
}
