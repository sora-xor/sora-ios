/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol HiddableBarWhenPushed: class {}

final class SoraNavigationController: UINavigationController, UINavigationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    override var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }

    private func setup() {
        delegate = self

        view.backgroundColor = .background

        navigationBar.prefersLargeTitles = true

        navigationBar.tintColor = SoraNavigationBarStyle.tintColor

        navigationBar.setBackgroundImage(SoraNavigationBarStyle.background,
                                         for: UIBarMetrics.default)
        navigationBar.shadowImage = SoraNavigationBarStyle.noShadow

        navigationBar.titleTextAttributes = SoraNavigationBarStyle.titleAttributes
    }

    // MARK: UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController,
                                     willShow viewController: UIViewController, animated: Bool) {
        handleDesignableNavigationIfNeeded(viewController: viewController)
    }

    // MARK: Private

    private func handleDesignableNavigationIfNeeded(viewController: UIViewController) {
        updateNavigationBarState(in: viewController)
        setupBackButtonItem(for: viewController)
    }

    private func updateNavigationBarState(in viewController: UIViewController) {
        let isHidden = viewController as? HiddableBarWhenPushed != nil
        setNavigationBarHidden(isHidden, animated: true)

        var navigationShadowStyle = NavigationBarSeparatorStyle.dark

        if let navigationBarDesignable = viewController as? DesignableNavigationBarProtocol {
            navigationShadowStyle = navigationBarDesignable.separatorStyle
        }

        switch navigationShadowStyle {
        case .dark:
            navigationBar.shadowImage = SoraNavigationBarStyle.darkShadow
        case .light:
            navigationBar.shadowImage = SoraNavigationBarStyle.lightShadow
        case .empty:
            navigationBar.shadowImage = UIImage()
        }
    }

    private func setupBackButtonItem(for viewController: UIViewController) {
        let backButtonItem = viewController.navigationItem.backBarButtonItem ?? UIBarButtonItem()
        backButtonItem.title = " "
        viewController.navigationItem.backBarButtonItem = backButtonItem
    }
}

extension SoraNavigationController: ScrollsToTop {
    func scrollToTop() {
        if let scrollableController = topViewController as? ScrollsToTop {
            scrollableController.scrollToTop()
        }
    }
}
