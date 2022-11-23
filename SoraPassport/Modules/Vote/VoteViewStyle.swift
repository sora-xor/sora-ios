import UIKit

struct VoteViewStyle {
    let voteTitle: String
    let voteIcon: UIImage?
    let tintColor: UIColor
    let thumbIcon: UIImage?
}

extension VoteViewStyle {
    static func projectStyle(for locale: Locale?) -> VoteViewStyle {
        let voteTitle = R.string.localizable
            .commonVote(preferredLanguages: locale?.rLanguages)
        let thumbIcon = R.image.imageThumb()
        return VoteViewStyle(voteTitle: voteTitle,
                             voteIcon: nil,
                             tintColor: R.color.brandSoramitsuRed()!,
                             thumbIcon: thumbIcon)
    }

    static func referendumStyle(for option: ReferendumVotingCase, locale: Locale?) -> VoteViewStyle {
        let title: String
        let icon: UIImage?
        let tintColor: UIColor
        let thumbIcon: UIImage?

        switch option {
        case .support:
            title = ""
            icon = R.image.iconThumbUp()?.tinted(with: .white)
            tintColor = R.color.brandSoramitsuRed()!
            thumbIcon = R.image.imageThumb()
        case .unsupport:
            title = ""
            icon = R.image.iconThumbDown()?.tinted(with: .white)
            tintColor = R.color.baseContentTertiary()!
            thumbIcon = R.image.imageThumbSilver()
        }

        return VoteViewStyle(voteTitle: title,
                             voteIcon: icon,
                             tintColor: tintColor,
                             thumbIcon: thumbIcon)
    }
}
