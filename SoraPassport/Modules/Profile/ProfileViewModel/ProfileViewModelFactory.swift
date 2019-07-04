/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol ProfileViewModelFactoryProtocol: class {
    func createUserViewModel(from userData: UserData?) -> ProfileUserViewModelProtocol
    func createOptionViewModels(from votesData: VotesData?,
                                reputationData: ReputationData?) -> [ProfileOptionViewModelProtocol]
}

enum ProfileOption: UInt, CaseIterable {
    case reputation
    case votes
    case personalDetails
    case passphrase
    case terms
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {
    private(set) var votesFormatter: NumberFormatter
    private(set) var integerFormatter: NumberFormatter

    init(votesFormatter: NumberFormatter, integerFormatter: NumberFormatter) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
    }

    func createUserViewModel(from userData: UserData?) -> ProfileUserViewModelProtocol {
        if let userData = userData {
            let name = "\(userData.firstName.capitalized) \(userData.lastName.capitalized)"
            let details = userData.email

            return ProfileUserViewModel(name: name, details: details)
        } else {
            return ProfileUserViewModel(name: "", details: "")
        }
    }

    func createOptionViewModels(from votesData: VotesData?,
                                reputationData: ReputationData?) -> [ProfileOptionViewModelProtocol] {
        let optionViewModels = ProfileOption.allCases.map { (option) -> ProfileOptionViewModel in
            switch option {
            case .reputation:
                let viewModel = ProfileOptionViewModel(title: R.string.localizable.profileOptionReputationTitle(),
                                                       icon: R.image.iconProfileReputation()!)

                if let rank = reputationData?.rank,
                    let rankString = integerFormatter.string(from: NSNumber(value: rank)),
                    let totalRank = reputationData?.ranksCount,
                    let totalRankString = integerFormatter.string(from: NSNumber(value: totalRank)) {

                    viewModel.accessoryTitle = R.string.localizable.profileOptionRankFormat(rankString, totalRankString)
                    viewModel.accessoryIcon = R.image.reputationIcon()
                }

                return viewModel

            case .votes:
                let viewModel = ProfileOptionViewModel(title: R.string.localizable.profileOptionVotesTitle(),
                                                       icon: R.image.voteButtonIcon()!)

                if let votesData = votesData {
                    viewModel.accessoryIcon = R.image.iconProfileVotes()

                    if let votes = Decimal(string: votesData.value) {
                        viewModel.accessoryTitle = votesFormatter.string(from: votes as NSNumber)
                    }
                }

                return viewModel

            case .personalDetails:
                return ProfileOptionViewModel(title: R.string.localizable.profileOptionPersonalDetailsTitle(),
                                              icon: R.image.iconProfilePerson()!)

            case .passphrase:
                return ProfileOptionViewModel(title: R.string.localizable.profileOptionPassphraseTitle(),
                                              icon: R.image.iconProfilePassphrase()!)
            case .terms:
                let viewModel = ProfileOptionViewModel(title: R.string.localizable.profileOptionTermsTitle(),
                                                       icon: R.image.iconTermsProfile()!)
                return viewModel
            }
        }

        return optionViewModels
    }

}
