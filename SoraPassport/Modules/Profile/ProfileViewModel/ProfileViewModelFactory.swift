import Foundation
import SoraFoundation

protocol ProfileViewModelFactoryProtocol: class {
    func createUserViewModel(from userData: UserData?) -> ProfileUserViewModelProtocol
    func createOptionViewModels(from votesData: VotesData?,
                                reputationData: ReputationData?,
                                language: Language?,
                                locale: Locale) -> [ProfileOptionViewModelProtocol]
}

enum ProfileOption: UInt, CaseIterable {
    case reputation
    case votes
    case personalDetails
    case passphrase
    case language
    case about
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {
    let votesFormatter: LocalizableResource<NumberFormatter>
    let integerFormatter: LocalizableResource<NumberFormatter>

    init(votesFormatter: LocalizableResource<NumberFormatter>,
         integerFormatter: LocalizableResource<NumberFormatter>) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
    }

    func createUserViewModel(from userData: UserData?) -> ProfileUserViewModelProtocol {
        if let userData = userData {
            let name = "\(userData.firstName.capitalized) \(userData.lastName.capitalized)"
            let details = userData.phone ?? ""

            return ProfileUserViewModel(name: name, details: details)
        } else {
            return ProfileUserViewModel(name: "", details: "")
        }
    }

    func createOptionViewModels(from votesData: VotesData?,
                                reputationData: ReputationData?,
                                language: Language?,
                                locale: Locale) -> [ProfileOptionViewModelProtocol] {

        let optionViewModels = ProfileOption.allCases.map { (option) -> ProfileOptionViewModel in
            switch option {
            case .reputation:
                return createReputationViewModel(from: reputationData, locale: locale)
            case .votes:
                return createVotesViewModel(from: votesData, locale: locale)
            case .personalDetails:
                return createPersonalDetailsViewModel(for: locale)
            case .passphrase:
                return createPassphraseViewModel(for: locale)
            case .language:
                return createLanguageViewModel(from: language, locale: locale)
            case .about:
                return createAboutViewModel(for: locale)
            }
        }

        return optionViewModels
    }

    private func createReputationViewModel(from reputationData: ReputationData?,
                                           locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileMyReputationTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(title: title,
                                               icon: R.image.iconProfileReputation()!)

        if let rank = reputationData?.rank,
            let rankString = integerFormatter.value(for: locale).string(from: NSNumber(value: rank)) {

            viewModel.accessoryTitle = rankString
            viewModel.accessoryIcon = R.image.reputationIcon()
        }

        return viewModel
    }

    private func createVotesViewModel(from votesData: VotesData?, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileVotesTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(title: title,
                                               icon: R.image.voteButtonIcon()!)

        if let votesData = votesData {
            viewModel.accessoryIcon = R.image.iconProfileVotes()

            if let votes = Decimal(string: votesData.value) {
                viewModel.accessoryTitle = votesFormatter.value(for: locale).string(from: votes as NSNumber)
            }
        }

        return viewModel
    }

    private func createPersonalDetailsViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileChangePersonalDetails(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(title: title, icon: R.image.iconProfilePerson()!)
    }

    private func createPassphraseViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profilePassphraseTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(title: title, icon: R.image.iconProfilePassphrase()!)
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileLanguageTitle(preferredLanguages: locale.rLanguages)
        let viewModel = ProfileOptionViewModel(title: title, icon: R.image.iconProfileLanguage()!)

        viewModel.accessoryTitle = language?.title(in: locale)?.capitalized

        return viewModel
    }

    private func createAboutViewModel(for locale: Locale) -> ProfileOptionViewModel {
        let title = R.string.localizable
            .profileAboutTitle(preferredLanguages: locale.rLanguages)
        return ProfileOptionViewModel(title: title, icon: R.image.iconTermsProfile()!)
    }
}
