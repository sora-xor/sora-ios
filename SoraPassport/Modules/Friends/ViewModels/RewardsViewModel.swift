import UIKit
import SoraFoundation

// MARK: - ViewModel

protocol RewardsViewModelProtocol {
    var icon: UIImage? { get }
    var title: String { get }
    var note: String { get }
    var amount: String { get }
    var date: String { get }
}

struct RewardsViewModel: RewardsViewModelProtocol {
    var icon: UIImage?
    let title: String
    let note: String
    let amount: String
    let date: String
}

// MARK: - ViewModel Factory

protocol RewardsViewModelFactoryProtocol: class {
    func createActivatedInvitationViewModel(from data: ActivatedInvitationsData,
                                            dateFormatter: LocalizableResource<DateFormatter>,
                                            locale: Locale) -> [RewardsViewModelProtocol]
}

// MARK: - Real Factory

final class RewardsViewModelFactory: RewardsViewModelFactoryProtocol {

    func createActivatedInvitationViewModel(from data: ActivatedInvitationsData,
                                            dateFormatter: LocalizableResource<DateFormatter>,
                                            locale: Locale) -> [RewardsViewModelProtocol] {
        return data.invitedUsers.map { invitation in
            return RewardsViewModel(
                icon: R.image.iconSora(),
                title: R.string.localizable.inviteAcceptedSomeone(preferredLanguages: locale.rLanguages),
                note: dateFormatter.value(for: locale).string(from: invitation.registrationDate),
                amount: "", date: ""
            )
        }
    }
}

// MARK: - Fake Factory

private let count: Int = 30

final class FakeFullRewardsViewModelFactory: RewardsViewModelFactoryProtocol {

    func createActivatedInvitationViewModel(from data: ActivatedInvitationsData,
                                            dateFormatter: LocalizableResource<DateFormatter>,
                                            locale: Locale) -> [RewardsViewModelProtocol] {
        return (0..<count).map { (_) in
            RewardsViewModel(
                icon: R.image.iconSora(),
                title: R.string.localizable.inviteAcceptedSomeone(preferredLanguages: locale.rLanguages),
                note: "–",
                amount: "+\(Int.random(in: 1...99)) VAL",
                date: dateFormatter.value(for: locale).string(from: Date())
            )
        }
    }
}

final class FakeShortRewardsViewModelFactory: RewardsViewModelFactoryProtocol {

    func createActivatedInvitationViewModel(from data: ActivatedInvitationsData,
                                            dateFormatter: LocalizableResource<DateFormatter>,
                                            locale: Locale) -> [RewardsViewModelProtocol] {
        return (0..<count).map { (_) in
            RewardsViewModel(
                icon: R.image.iconSora(),
                title: R.string.localizable.inviteAcceptedSomeone(preferredLanguages: locale.rLanguages),
                note: dateFormatter.value(for: locale).string(from: Date()),
                amount: "",
                date: ""
            )
        }
    }
}
