/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit

class SplashViewController: UIViewController, SplashViewProtocol {

    var presenter: SplashPresenter!

    private lazy var splash: SplashView = {
        return R.nib.launchScreen(owner: nil)!
    }()

    override func loadView() {
        view = splash
    }

    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        splash.animate(duration: animationDurationBase, completion: completion)
    }
}
