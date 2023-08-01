import Foundation
import UIKit
import CommonWallet
import SoraUIKit

final class FriendsWireframe: FriendsWireframeProtocol {

    private(set) var walletContext: CommonWalletContextProtocol
    private(set) var assetManager: AssetManagerProtocol

    init(walletContext: CommonWalletContextProtocol,
         assetManager: AssetManagerProtocol) {
        self.walletContext = walletContext
        self.assetManager = assetManager
    }

    func showLinkInputViewController(from controller: UIViewController, delegate: InputLinkPresenterOutput) {
        guard
            let inputLinkController = ReferralViewFactory.createInputLinkView(with: delegate),
            let navigationController = controller.navigationController
        else { return }
        
        navigationController.pushViewController(inputLinkController, animated: true)
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
        guard let navigationController = controller.navigationController else { return }
        let viewController = ReferralViewFactory.createReferrerView(with: referrer)
        navigationController.pushViewController(viewController, animated: true)
    }

    func showActivityViewController(from controller: UIViewController, shareText: String) {
        let textToShare = [ shareText ]
        let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [ UIActivity.ActivityType.airDrop, UIActivity.ActivityType.postToFacebook ]
        controller.present(activityViewController, animated: true, completion: nil)
    }
    
    func showActivityDetails(from controller: UIViewController?, model: Transaction, completion: (() -> Void)?) {
        guard let activityDetailsController = ReferralViewFactory.createActivityDetailsView(assetManager: assetManager,
                                                                                            model: model,
                                                                                            completion: completion),
              let controller = controller
        else {
            return
        }
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.completionHandler = completion
        containerView.add(activityDetailsController)
        
        controller.present(containerView, animated: true)
    }
    
    func setViewControllers(from controller: UIViewController?, currentController: UIViewController?, referrer: String) {
        guard
            let navigationController = controller?.navigationController,
            let friendsView = currentController
        else { return }
        
        let referrerView = ReferralViewFactory.createReferrerView(with: referrer)
        
        navigationController.setViewControllers([friendsView, referrerView], animated: true)
    }
}
