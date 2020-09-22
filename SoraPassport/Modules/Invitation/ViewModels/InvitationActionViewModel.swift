import UIKit

enum InvitationActionStyle {
    case normal
    case critical
}

struct InvitationActionViewModel {
    let title: String
    let icon: UIImage?
    let accessoryText: String?
    let style: InvitationActionStyle
}
