//import UIKit
//
//extension UIColor {
//    static var darkGreyish: UIColor {
//        return UIColor(red: 3.0 / 255.0, green: 92.0 / 255.0, blue: 90.0 / 255.0, alpha: 1.0)
//    }
//
//    static var greyish: UIColor {
//        return UIColor(red: 115.0 / 255.0,
//                       green: 168.0 / 255.0,
//                       blue: 166.0 / 255.0,
//                       alpha: 1.0)
//    }
//
//    static var coolGrey: UIColor {
//        return UIColor(red: 137.0 / 255.0,
//                       green: 159.0 / 255.0,
//                       blue: 158.0 / 255.0,
//                       alpha: 1.0)
//    }
//
//    static var silver: UIColor {
//        return UIColor(red: 0.459, green: 0.471, blue: 0.482, alpha: 1)
//    }
//
//    static var darkRed: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var background: UIColor {
//        return UIColor.white//(red: 242.0 / 255.0, green: 247.0 / 255.0, blue: 247.0 / 255.0, alpha: 1.0)
//    }
//
//    static var navigationBarTitleColor: UIColor {
//        return UIColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)
//    }
//
//    static var navigationBarBackTintColor: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var lightNavigationShadowColor: UIColor {
//        return UIColor(red: 198.0 / 255.0, green: 231.0 / 255.0, blue: 224.0 / 255.0, alpha: 1.0)
//    }
//
//    static var darkNavigationShadowColor: UIColor {
//        return UIColor(red: 153.0 / 255.0, green: 153.0 / 255.0, blue: 153.0 / 255.0, alpha: 0.25)
//    }
//
//    static var navigationBarColor: UIColor {
//        return .white
//    }
//
//    static var scrollableNavigationBar: UIColor {
//        return UIColor(red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)
//    }
//
//    static var scrollableNavigationBarShadow: UIColor {
//        return UIColor(red: 131.0 / 255.0, green: 145.0 / 255.0, blue: 146.0 / 255.0, alpha: 0.389)
//    }
//
//    static var networkUnavailableBackground: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var networkAvailableBackground: UIColor {
//        return UIColor(red: 50.0 / 255.0, green: 205.0 / 255.0, blue: 50.0 / 255.0, alpha: 1.0)
//    }
//
//    static var notificationBackground: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var inputIndicator: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var loadingBackground: UIColor {
//        return UIColor.black.withAlphaComponent(0.19)
//    }
//
//    static var loadingContent: UIColor {
//        return UIColor.white
//    }
//
//    static var tabBarBackground: UIColor {
//        return .white
//    }
//
//    static var tabBarShadow: UIColor {
//        return UIColor(red: 96.0 / 255.0, green: 96.0 / 255.0, blue: 96.0 / 255.0, alpha: 0.38)
//    }
//
//    @available(*, deprecated, message: "Will be removed")
//    static var tabBarItemNormal: UIColor {
//        return UIColor(red: 0.459, green: 0.471, blue: 0.482, alpha: 1)
//    }
//
//    @available(*, deprecated, message: "Will be removed")
//    static var tabBarItemSelected: UIColor {
//        return UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1)
//    }
//
//    static var barVotes: UIColor {
//        return UIColor(red: 28.0 / 255.0, green: 80.0 / 255.0, blue: 78.0 / 255.0, alpha: 1.0)
//    }
//
//    static var barButtonTitle: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var activityType: UIColor {
//        return UIColor(red: 123.0 / 255.0, green: 123.0 / 255.0, blue: 123.0 / 255.0, alpha: 1.0)
//    }
//
//    static var activityTimestamp: UIColor {
//        return UIColor(red: 189.0 / 255.0, green: 189.0 / 255.0, blue: 189.0 / 255.0, alpha: 1.0)
//    }
//
//    static var activityTitle: UIColor {
//        return UIColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)
//    }
//
//    static var activityDetails: UIColor {
//        return UIColor(red: 46.0 / 255.0, green: 46.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0)
//    }
//
//    static var activityAmount: UIColor {
//        return UIColor(red: 46.0 / 255.0, green: 46.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0)
//    }
//
//    static var helpLeadingItemTitle: UIColor {
//        return UIColor(red: 3.0 / 255.0, green: 92.0 / 255.0, blue: 90.0 / 255.0, alpha: 1.0)
//    }
//
//    static var helpLeadingItemDetails: UIColor {
//        return UIColor(red: 123.0 / 255.0, green: 123.0 / 255.0, blue: 123.0 / 255.0, alpha: 1.0)
//    }
//
//    static var helpNormalItemTitle: UIColor {
//        return UIColor(red: 46.0 / 255.0, green: 46.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0)
//    }
//
//    static var helpNormalItemDetails: UIColor {
//        return UIColor(red: 46.0 / 255.0, green: 46.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0)
//    }
//
//    static var helpItemSeparatorColor: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var emptyStateTitle: UIColor {
//        return UIColor(red: 157.0 / 255.0, green: 179.0 / 255.0, blue: 177.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectCardTitle: UIColor {
//        return UIColor(red: 46.0 / 255.0, green: 46.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectCardDetails: UIColor {
//        return UIColor(red: 46.0 / 255.0, green: 46.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectCardFavorite: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectCardReward: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var openedProjectProgressDetails: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var openedProjectDeadline: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var openedProjectVotingState: UIColor {
//        return UIColor(red: 228.0 / 255.0, green: 35.0 / 255.0, blue: 45.0 / 255.0, alpha: 1.0)
//    }
//
//    static var openedProjectFriendsVoted: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var finishedProjectFundingProgressDetails: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var finishedProjectCompletionDetails: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var finishedProjectVotingTitle: UIColor {
//        return UIColor(red: 121.0 / 255.0, green: 146.0 / 255.0, blue: 146.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectDetailsVoteBackgroundWhenOpen: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectDetailsVoteBackgroundWhenFinished: UIColor {
//        return UIColor(red: 240.0 / 255.0, green: 247.0 / 255.0, blue: 246.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectDetailsVoteTitleWhenOpen: UIColor {
//        return UIColor(red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)
//    }
//
//    static var projectDetailsVoteTitleWhenFinished: UIColor {
//        return UIColor(red: 28.0 / 255.0, green: 80.0 / 255.0, blue: 78.0 / 255.0, alpha: 1.0)
//    }
//
//    static var voteDescriptionNormal: UIColor {
//        return UIColor(red: 157.0 / 255.0, green: 157.0 / 255.0, blue: 157.0 / 255.0, alpha: 1.0)
//    }
//
//    static var voteDescriptionError: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var voteMinimumTrack: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var voteMaximumTrack: UIColor {
//        return UIColor(red: 240.0 / 255.0, green: 247.0 / 255.0, blue: 247.0 / 255.0, alpha: 1.0)
//    }
//
//    static var searchBarField: UIColor {
//        return UIColor(red: 142.0 / 255.0, green: 142.0 / 255.0, blue: 147.0 / 255.0, alpha: 0.12)
//    }
//
//    static var accessoryTitle: UIColor {
//        return .black
//    }
//
//    static var actionTitle: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var listSeparator: UIColor {
//        return UIColor(white: 153.0 / 255.0, alpha: 0.25)
//    }
//
//    static var verifyIdentityEnabledStepTitle: UIColor {
//        return UIColor.black
//    }
//
//    static var verifyIdentityDisabledStepTitle: UIColor {
//        return UIColor(white: 97.0 / 255.0, alpha: 1.0)
//    }
//
//    static var verificationEnabledSeparator: UIColor {
//        return UIColor(red: 208.0 / 255.0, green: 2.0 / 255.0, blue: 27.0 / 255.0, alpha: 1.0)
//    }
//
//    static var verificationDisabledSeparator: UIColor {
//        return UIColor(white: 153.0 / 255.0, alpha: 0.25)
//    }
//}
