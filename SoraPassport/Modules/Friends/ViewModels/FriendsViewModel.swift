import Foundation
import SoraFoundation

// MARK: - ViewModel

protocol FriendsInvitationViewModelProtocol {
    var canAcceptInvitation: Bool { get }
    var invitationCode: String { get }
}

struct FriendsInvitationViewModel: FriendsInvitationViewModelProtocol {
    var canAcceptInvitation: Bool
    var invitationCode: String

    init(canAcceptInvitation: Bool, invitationCode: String) {
        self.canAcceptInvitation = canAcceptInvitation
        self.invitationCode = invitationCode
    }
}

// MARK: - ViewModel Factory

protocol FriendsViewModelFactoryProtocol {
    func createActionListViewModel(
        from userData: UserData?) -> FriendsInvitationViewModelProtocol

    func createActionAccessory(
        for preferredLanguages: [String]?,
        from remainedInterval: TimeInterval,
        notificationInterval: TimerNotificationInterval) -> String
}

// MARK: - Real Factory

final class FriendsViewModelFactory: FriendsViewModelFactoryProtocol {
    func createActionListViewModel(
        from userData: UserData?) -> FriendsInvitationViewModelProtocol {

        let viewModel = FriendsInvitationViewModel(
            canAcceptInvitation: userData?.canAcceptInvitation ?? false,
            invitationCode: userData?.values.invitationCode ?? "")

        return viewModel
    }

    func createActionAccessory(
        for preferredLanguages: [String]?,
        from remainedInterval: TimeInterval,
        notificationInterval: TimerNotificationInterval) -> String {

        let timeFormatter: TimeFormatterProtocol
        let hms: (String, String)

        switch notificationInterval {
        case .second:
            timeFormatter = MinuteSecondFormatter()
            hms = (
                R.string.localizable.inviteCodeLeftMinutes(preferredLanguages: preferredLanguages),
                R.string.localizable.inviteCodeLeftSeconds(preferredLanguages: preferredLanguages)
            )
        case .minute:
            timeFormatter = HourMinuteFormatter()
            hms = (
                R.string.localizable.inviteCodeLeftHours(preferredLanguages: preferredLanguages),
                R.string.localizable.inviteCodeLeftMinutes(preferredLanguages: preferredLanguages)
            )
        }

        guard let string = try? timeFormatter.string(from: remainedInterval) else {
            return ""
        }

        let parts = string.split(separator: ":").map { String($0) }
        return "\(parts[0])\(hms.0) \(parts[1])\(hms.1)"
    }
}

// MARK: - Fake Factory

final class FakeFriendsViewModelFactory: FriendsViewModelFactoryProtocol {
    func createActionListViewModel(
        from userData: UserData?) -> FriendsInvitationViewModelProtocol {
        return FriendsInvitationViewModel(
            canAcceptInvitation: true,
            invitationCode: "1234AB0Z"
        )
    }

    func createActionAccessory(
        for preferredLanguages: [String]?,
        from remainedInterval: TimeInterval,
        notificationInterval: TimerNotificationInterval) -> String {
        return "[> 99h 59m <]"
    }
}
