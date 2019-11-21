/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

protocol ActivityFeedViewModelFactoryDelegate: class {
    func activityFeedViewModelFactoryDidChange(_ factory: ActivityFeedViewModelFactoryProtocol)
}

protocol ActivityFeedViewModelFactoryProtocol {
    var delegate: ActivityFeedViewModelFactoryDelegate? { get set }

    func merge(activity: ActivityData,
               into existingViewModels: inout [ActivityFeedSectionViewModel],
               using metadataContainer: ActivityFeedLayoutMetadataContainer) throws
        -> [SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>]
}

typealias SectionedActivityFeedItemViewModel =
    (sectionTitle: String, itemViewModel: ActivityFeedOneOfItemViewModel)

final class ActivityFeedViewModelFactory {
    private(set) var timestampDateFormatter: DateFormatter
    private(set) var votesNumberFormatter: NumberFormatter
    private(set) var amountFormatter: NumberFormatter
    private(set) var integerFormatter: NumberFormatter

    weak var delegate: ActivityFeedViewModelFactoryDelegate?

    let sectionFormatterProvider: DateFormatterProviderProtocol

    init(sectionFormatterProvider: DateFormatterProviderProtocol,
         timestampDateFormatter: DateFormatter,
         votesNumberFormatter: NumberFormatter,
         amountFormatter: NumberFormatter,
         integerFormatter: NumberFormatter) {
        self.sectionFormatterProvider = sectionFormatterProvider
        self.timestampDateFormatter = timestampDateFormatter
        self.votesNumberFormatter = votesNumberFormatter
        self.amountFormatter = amountFormatter
        self.integerFormatter = integerFormatter

        sectionFormatterProvider.delegate = self
    }
}

private typealias SearchableSection = (section: ActivityFeedSectionViewModel, index: Int)

extension ActivityFeedViewModelFactory: ActivityFeedViewModelFactoryProtocol {
    func merge(activity: ActivityData,
               into existingViewModels: inout [ActivityFeedSectionViewModel],
               using metadataContainer: ActivityFeedLayoutMetadataContainer) throws
        -> [SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>] {

        var searchableSections = [String: SearchableSection]()
        for (index, section) in existingViewModels.enumerated() {
            searchableSections[section.title] = SearchableSection(section: section, index: index)
        }

        var changes = [SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>]()

        activity.events.forEach { oneOfEvent in
            let optionalSectionedViewModel = transform(event: oneOfEvent,
                                                       from: activity,
                                                       metadataContainer: metadataContainer)

            guard let newSectionedViewModel = optionalSectionedViewModel else {
                return
            }

            let newViewModel = newSectionedViewModel.itemViewModel

            let sectionTitle = newSectionedViewModel.sectionTitle

            if let searchableSection = searchableSections[sectionTitle] {
                let itemChange = ListDifference.insert(index: searchableSection.section.items.count, new: newViewModel)
                let sectionChange = SectionedListDifference.update(index: searchableSection.index,
                                                                   itemChange: itemChange,
                                                                   section: searchableSection.section)
                changes.append(sectionChange)

                searchableSection.section.items.append(newViewModel)
            } else {
                let newSection = ActivityFeedSectionViewModel(title: sectionTitle,
                                                              items: [newViewModel])

                let change: SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>
                    = .insert(index: searchableSections.count, newSection: newSection)

                changes.append(change)

                let searchableSection = SearchableSection(section: newSection, index: existingViewModels.count)
                searchableSections[newSection.title] = searchableSection

                existingViewModels.append(newSection)
            }

        }

        return changes
    }
}

extension ActivityFeedViewModelFactory: DateFormatterProviderDelegate {
    func providerDidChangeDateFormatter(_ provider: DateFormatterProviderProtocol) {
        delegate?.activityFeedViewModelFactoryDidChange(self)
    }
}
