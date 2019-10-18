/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ReputationViewModelFactoryProtocol {
    func createEmptyRankTitle(for remainingDelay: TimeInterval) -> String
    func createReputationDetailsViewModel(from data: ReputationDetailsData) throws -> ReputationDetailsViewModel
}

enum ReputationViewModelFactoryError: Error {
    case missingMainParagraph
    case missingStepsTitle
}

struct ReputationViewModelFactory: ReputationViewModelFactoryProtocol {
    let timeFormatter: TimeFormatterProtocol

    init(timeFormatter: TimeFormatterProtocol) {
        self.timeFormatter = timeFormatter
    }

    func createEmptyRankTitle(for remainingDelay: TimeInterval) -> String {
        if remainingDelay > 0.0, let time = try? timeFormatter.string(from: remainingDelay) {
            return R.string.localizable.reputationCalculationTime(time)
        } else {
            return R.string.localizable.reputationCalculationSoon()
        }
    }

    func createReputationDetailsViewModel(from data: ReputationDetailsData) throws -> ReputationDetailsViewModel {
        var index = 0

        guard let mainParagraphData = data.topics["\(index)"] else {
            throw ReputationViewModelFactoryError.missingMainParagraph
        }

        index += 1

        guard let stepsTitleData = data.topics["\(index)"] else {
            throw ReputationViewModelFactoryError.missingStepsTitle
        }

        index += 1

        var steps: [StepViewModel] = []

        while let stepData = data.topics["\(index)"] {
            let step = StepViewModel(index: index - 1, title: stepData.description)
            steps.append(step)

            index += 1
        }

        return ReputationDetailsViewModel(mainTitle: mainParagraphData.title,
                                          mainText: mainParagraphData.description,
                                          stepsTitle: stepsTitleData.title,
                                          steps: steps)
    }
}
