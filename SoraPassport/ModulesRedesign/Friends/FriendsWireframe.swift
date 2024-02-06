// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
