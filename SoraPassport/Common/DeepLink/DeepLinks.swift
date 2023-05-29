import Foundation

struct InvitationDeepLink: DeepLinkProtocol {
    let code: String

    func accept(navigator: DeepLinkNavigatorProtocol) -> Bool {
        return navigator.navigate(to: self)
    }
}
