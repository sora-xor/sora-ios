import Foundation
import UIKit
import CommonWallet
import SoraUIKit

final class FriendsWireframe: FriendsWireframeProtocol {

    private(set) var walletContext: CommonWalletContextProtocol

    init(walletContext: CommonWalletContextProtocol) {
        self.walletContext = walletContext
    }

    func showLinkInputViewController(from controller: UIViewController, delegate: InputLinkPresenterOutput) {
        guard let viewController = ReferralViewFactory.createInputLinkView(with: delegate) else { return }
        controller.present(viewController, animated: true, completion: nil)
    }

    func showInputRewardAmountViewController(from controller: UIViewController,
                                             fee: Decimal,
                                             bondedAmount: Decimal,
                                             type: InputRewardAmountType,
                                             delegate: InputRewardAmountPresenterOutput) {

        guard let viewController = ReferralViewFactory.createInputRewardAmountView(with: fee,
                                                                                   bondedAmount: bondedAmount,
                                                                                   type: type,
                                                                                   walletContext: walletContext,
                                                                                   delegate: delegate),
              let navigationController = controller.navigationController
        else {
            return
        }
        
        navigationController.pushViewController(viewController, animated: true)
    }

    func showReferrerScreen(from controller: UIViewController, referrer: String) {
        let viewController = ReferralViewFactory.createReferrerView(with: referrer)
        controller.present(viewController, animated: true, completion: nil)
    }

    func showActivityViewController(from controller: UIViewController, shareText: String) {
        let textToShare = [ shareText ]
        let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [ UIActivity.ActivityType.airDrop, UIActivity.ActivityType.postToFacebook ]
        controller.present(activityViewController, animated: true, completion: nil)
    }
}
