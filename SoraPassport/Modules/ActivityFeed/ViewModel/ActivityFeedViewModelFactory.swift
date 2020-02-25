/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import SoraFoundation

protocol ActivityFeedViewModelFactoryDelegate: class {
    func activityFeedViewModelFactoryDidChange(_ factory: ActivityFeedViewModelFactoryProtocol)
}

protocol ActivityFeedViewModelFactoryProtocol: class {
    var delegate: ActivityFeedViewModelFactoryDelegate? { get set }

    func merge(activity: ActivityData,
               into existingViewModels: inout [ActivityFeedSectionViewModel],
               using metadataContainer: ActivityFeedLayoutMetadataContainer,
               locale: Locale) throws
        -> [SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>]
}

typealias SectionedActivityFeedItemViewModel =
    (sectionTitle: String, itemViewModel: ActivityFeedOneOfItemViewModel)

final class ActivityFeedViewModelFactory {
    private(set) var timestampDateFormatter: LocalizableResource<DateFormatter>
    private(set) var votesNumberFormatter: LocalizableResource<NumberFormatter>
    private(set) var amountFormatter: LocalizableResource<NumberFormatter>
    private(set) var integerFormatter: LocalizableResource<NumberFormatter>

    weak var delegate: ActivityFeedViewModelFactoryDelegate?

    private(set) var sectionFormatterProvider: DateFormatterProviderProtocol

    init(sectionFormatterProvider: DateFormatterProviderProtocol,
         timestampDateFormatter: LocalizableResource<DateFormatter>,
         votesNumberFormatter: LocalizableResource<NumberFormatter>,
         amountFormatter: LocalizableResource<NumberFormatter>,
         integerFormatter: LocalizableResource<NumberFormatter>) {

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
               using metadataContainer: ActivityFeedLayoutMetadataContainer,
               locale: Locale) throws
        -> [SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>] {

        var searchableSections = [String: SearchableSection]()
        for (index, section) in existingViewModels.enumerated() {
            searchableSections[section.title] = SearchableSection(section: section, index: index)
        }

        var changes = [SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>]()

        activity.events.forEach { oneOfEvent in
            let optionalSectionedViewModel = transform(event: oneOfEvent,
                                                       from: activity,
                                                       metadataContainer: metadataContainer,
                                                       locale: locale)

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
