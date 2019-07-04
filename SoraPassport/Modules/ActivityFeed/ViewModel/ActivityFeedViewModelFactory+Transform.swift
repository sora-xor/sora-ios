/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension ActivityFeedViewModelFactory {
    func transform(event: ActivityOneOfEventData,
                   from activity: ActivityData,
                   and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel? {

            switch event {
            case .friendRegistered(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .votingRightsCredited(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .userRankChanged(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .invitationsCredited(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .projectFunded(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .projectClosed(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .projectCreated(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .xorTransfered(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .xorRewardCreditedFromProject(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            case .userHasVoted(let concreteEvent):
                return transform(event: concreteEvent, from: activity, and: metadataContainer)
            default:
                return nil
            }
    }

    private func transformSection(timestamp: Int64) -> String {
        return sectionDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private func transformActivity(timestamp: Int64) -> String {
        return timestampDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private func transform(event: FriendRegisteredEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityUser()
                $0.type = R.string.localizable.activityEventFriendRegisteredType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                if let userInfo = activity.users?[event.userId] {
                    $0.title = "\(userInfo.firstName) \(userInfo.lastName)"
                    $0.details = R.string.localizable.activityEventFriendRegisteredDetails()
                } else {
                    $0.details = R.string.localizable.activityEventFriendRegisteredDetails()
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: VotingRightsCreditedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedAmountItemContent {
                $0.icon = R.image.iconActivityVote()
                $0.type = R.string.localizable.activityEventVotesCreditedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                let votingRights = Decimal(string: event.votingRights) ?? 0
                let votesString = votesNumberFormatter.string(from: (votingRights as NSNumber)) ?? ""
                $0.details = R.string.localizable.activityEventVotesCreditedTitle()

                $0.amountStateIcon = R.image.increaseIcon()
                $0.amountText = votesString
                $0.amountSymbolIcon = R.image.activityVotesIcon()
            }

            let layout = createLayout(for: content, metadata: metadataContainer.amountLayoutMetadata)

            let viewModel = ActivityFeedAmountItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .amount(concreteViewModel: viewModel))
    }

    private func transform(event: UserRankChangedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityRank()
                $0.type = R.string.localizable.activityEventRankChangeType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                if let rankString = integerFormatter.string(from: NSNumber(value: event.rank)),
                    let totalRankString = integerFormatter.string(from: NSNumber(value: event.totalRank)) {
                    $0.details = R.string.localizable.activityEventRankChangeTitle(rankString, totalRankString)
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: InvitationsCreditedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityUser()
                $0.type = R.string.localizable.activityEventInvitationsCreditedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                if let invitationsCountString = integerFormatter.string(from: NSNumber(value: event.invitations)) {
                    $0.details = R.string.localizable.activityEventInvitationsCreditedTitle(invitationsCountString)
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: ProjectFundedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable.activityEventProjectFundedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                if let project = activity.projects?[event.projectId] {
                    $0.title = project.name
                    $0.details = R.string.localizable.activityEventProjectFundedDetails()
                } else {
                    $0.details = R.string.localizable.activityEventProjectFundedDefault()
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: ProjectClosedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable.activityEventProjectClosedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                if let project = activity.projects?[event.projectId] {
                    $0.title = project.name
                } else {
                    $0.details = R.string.localizable.activityEventProjectClosedDefault()
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: ProjectCreatedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable.activityEventProjectCreatedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)
                $0.title = event.name
                $0.details = event.description
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }

    private func transform(event: XORTransferedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedAmountItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable.activityEventXorTransferedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                let xor = Decimal(string: event.amount) ?? 0
                let amountString = amountFormatter.string(from: (xor as NSNumber)) ?? ""

                if let userInfo = activity.users?[event.source] {
                    $0.details = "\(userInfo.firstName) \(userInfo.lastName)"
                } else {
                    $0.details = R.string.localizable.activityEventXorTransferedDefaultTitle()
                }

                $0.amountStateIcon = R.image.increaseIcon()
                $0.amountText = String.xor + amountString
            }

            let layout = createLayout(for: content, metadata: metadataContainer.amountLayoutMetadata)

            let viewModel = ActivityFeedAmountItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .amount(concreteViewModel: viewModel))
    }

    private func transform(event: XORRewardCreditedFromProjectEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {
            let content = ActivityFeedAmountItemContent {
                $0.icon = R.image.iconActivityProject()
                $0.type = R.string.localizable.activityEventXorProjectCreditedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                let reward = Decimal(string: event.reward) ?? 0
                let rewardString = amountFormatter.string(from: reward as NSNumber) ?? ""

                if let project = activity.projects?[event.projectId] {
                    $0.details = project.name
                } else {
                    $0.details = R.string.localizable.activityEventXorProjectCreditedDetails()
                }

                $0.amountStateIcon = R.image.increaseIcon()
                $0.amountText = String.xor + rewardString
            }

            let layout = createLayout(for: content, metadata: metadataContainer.amountLayoutMetadata)

            let viewModel = ActivityFeedAmountItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .amount(concreteViewModel: viewModel))
    }

    private func transform(event: UserHasVotedEventData,
                           from activity: ActivityData,
                           and metadataContainer: ActivityFeedLayoutMetadataContainer)
        -> SectionedActivityFeedItemViewModel {

            let content = ActivityFeedItemContent {
                $0.icon = R.image.iconActivityVote()
                $0.type = R.string.localizable.activityEventUserHasVotedType()
                $0.timestamp = transformActivity(timestamp: event.issuedAt)

                let givenVotes = Decimal(string: event.givenVotes) ?? 0
                let givenVotesString = votesNumberFormatter.string(from: givenVotes as NSNumber) ?? ""

                if let user = activity.users?[event.userId], let project = activity.projects?[event.projectId] {
                    $0.title = "\(user.firstName) \(user.lastName)"
                    $0.details = R.string.localizable.activityEventUserHasVotedDetails(user.firstName,
                                                                                       givenVotesString,
                                                                                       project.name)
                } else {
                    $0.title = R.string.localizable.activityEventUserHasVotedDefault()
                }
            }

            let layout = createLayout(for: content, metadata: metadataContainer.basicLayoutMetadata)

            let viewModel = ActivityFeedItemViewModel(content: content, layout: layout)

            return SectionedActivityFeedItemViewModel(sectionTitle: transformSection(timestamp: event.issuedAt),
                                                      itemViewModel: .basic(concreteViewModel: viewModel))
    }
}
