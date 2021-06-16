/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol SplashPresenterProtocol: class {
    func present(in window: UIWindow, duration: Double, completion: @escaping () -> Void)
}

final class SplashPresenter: SplashPresenterProtocol {

    private lazy var view: SplashView = {
        return R.nib.launchScreen(owner: nil)!
    }()

    private func add(view: UIView, to parentView: UIView) {
        parentView.addSubview(view)
        view.frame = parentView.bounds
        view.center = parentView.center
    }

    func present(in window: UIWindow, duration: Double, completion: @escaping () -> Void) {
        if let root = window.rootViewController,
           let rootView = root.view {
            add(view: view, to: rootView)
            view.animate(duration: duration, completion: {
                self.view.removeFromSuperview()
                completion()
            })
        } else {
            completion()
        }
    }
}
