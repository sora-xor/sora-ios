/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

protocol VotesHistoryViewModelFactoryProtocol {
    func merge(newItems: [VotesHistoryEventData],
               into existingViewModels: inout [VotesHistorySectionViewModel]) throws
        -> [SectionedListDifference<VotesHistorySectionViewModel, VotesHistoryItemViewModel>]
}

enum VotesHistoryViewModelFactoryError: Error {
    case invalidEventAmount
    case amountFormattingFailed
    case timestampFormattingFailed
}

final class VotesHistoryViewModelFactory {
    private(set) var dateFormatter: DateFormatter
    private(set) var amountFormatter: NumberFormatter

    init(dateFormatter: DateFormatter, amountFormatter: NumberFormatter) {
        self.dateFormatter = dateFormatter
        self.amountFormatter = amountFormatter
    }

    private func createViewModel(from event: VotesHistoryEventData) throws -> VotesHistoryItemViewModel {
        guard let amountValue = Decimal(string: event.votes) else {
            throw VotesHistoryViewModelFactoryError.invalidEventAmount
        }

        let eventType: VotesHistoryItemType = amountValue > 0.0 ? .increase : .decrease

        guard let amountDisplayString = amountFormatter.string(from: (abs(amountValue) as NSNumber)) else {
            throw VotesHistoryViewModelFactoryError.amountFormattingFailed
        }

        return VotesHistoryItemViewModel(title: event.message,
                                         amount: amountDisplayString,
                                         type: eventType)
    }
}

private typealias SearchableSection = (section: VotesHistorySectionViewModel, index: Int)

extension VotesHistoryViewModelFactory: VotesHistoryViewModelFactoryProtocol {
    func merge(newItems: [VotesHistoryEventData],
               into existingViewModels: inout [VotesHistorySectionViewModel]) throws
        -> [SectionedListDifference<VotesHistorySectionViewModel, VotesHistoryItemViewModel>] {

        var searchableSections = [String: SearchableSection]()
        for (index, section) in existingViewModels.enumerated() {
            searchableSections[section.title] = SearchableSection(section: section, index: index)
        }

        var changes = [SectionedListDifference<VotesHistorySectionViewModel, VotesHistoryItemViewModel>]()

        try newItems.forEach { (event) in
            let viewModel = try self.createViewModel(from: event)

            let eventDate = Date(timeIntervalSince1970: TimeInterval(event.timestamp))
            let sectionTitle = dateFormatter.string(from: eventDate)

            if let searchableSection = searchableSections[sectionTitle] {
                let itemChange = ListDifference.insert(index: searchableSection.section.items.count, new: viewModel)
                let sectionChange = SectionedListDifference.update(index: searchableSection.index,
                                                                   itemChange: itemChange,
                                                                   newSection: searchableSection.section)
                changes.append(sectionChange)

                searchableSection.section.items.append(viewModel)
            } else {
                let newSection = VotesHistorySectionViewModel(title: sectionTitle,
                                                              items: [viewModel])

                let change: SectionedListDifference<VotesHistorySectionViewModel, VotesHistoryItemViewModel>
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
