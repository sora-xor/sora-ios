/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class MainTabBarViewController: UITabBarController {
	var presenter: MainTabBarPresenterProtocol!

    private var viewAppeared: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTabBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.viewIsReady()
        }
    }

    private func configureTabBar() {
        tabBar.backgroundImage = UIImage.background(from: UIColor.tabBarBackground)
        tabBar.shadowImage = UIImage.background(from: UIColor.tabBarShadow)
    }
}

extension MainTabBarViewController: MainTabBarViewProtocol {}
