import UIKit

protocol DeepLinkNavigatorProtocol {
    func navigate(to invitation: InvitationDeepLink) -> Bool
}

protocol DeepLinkProtocol {
    func accept(navigator: DeepLinkNavigatorProtocol) -> Bool
}
