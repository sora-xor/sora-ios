// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import UIKit

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
    
    @MainActor func showActivityDetails(from controller: UIViewController?, model: Transaction, completion: (() -> Void)?) {
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
