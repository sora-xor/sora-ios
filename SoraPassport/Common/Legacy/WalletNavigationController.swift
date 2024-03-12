//
//  WalletNavigationController.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import UIKit

enum WalletBarShadowType {
    case empty
    case singleLine
}

public protocol WalletNavigationBarConcealable: AnyObject {}

protocol WalletDesignableBar: AnyObject {
    var shadowType: WalletBarShadowType { get }
}

final class WalletNavigationController: UINavigationController, UINavigationControllerDelegate {

    var navigationBarStyle: WalletNavigationBarStyleProtocol? {
        didSet {
            if viewIfLoaded != nil {
                applyStyle()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    override var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }

    private func setup() {
        delegate = self

        applyStyle()
    }

    private func applyStyle() {
        if let navigationBarStyle = navigationBarStyle {
            navigationBar.tintColor = navigationBarStyle.itemTintColor

            navigationBar.setBackgroundImage(UIImage.background(from: navigationBarStyle.barColor),
                                             for: UIBarMetrics.default)

            var titleTextAttributes = navigationBar.titleTextAttributes ?? [NSAttributedString.Key: Any]()
            titleTextAttributes[.foregroundColor] = navigationBarStyle.titleColor
            titleTextAttributes[.font] = navigationBarStyle.titleFont

            navigationBar.titleTextAttributes = titleTextAttributes

            if let topViewController = topViewController {
                updateShadowState(for: topViewController)
            } else {
                navigationBar.shadowImage = UIImage.background(from: navigationBarStyle.shadowColor)
            }

            if let backButtonImage = navigationBarStyle.backButtonImage {
                navigationBar.backIndicatorImage = backButtonImage
                navigationBar.backIndicatorTransitionMaskImage = backButtonImage
            }
        }
    }

    // MARK: UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController,
                                     willShow viewController: UIViewController, animated: Bool) {
        handleDesignableNavigationIfNeeded(viewController: viewController)
    }

    // MARK: Private

    private func handleDesignableNavigationIfNeeded(viewController: UIViewController) {
        updateNavigationBarState(in: viewController)
        updateShadowState(for: viewController)
        setupBackButtonItem(for: viewController)
    }

    private func updateNavigationBarState(in viewController: UIViewController) {
        let isHidden = viewController as? WalletNavigationBarConcealable != nil
        setNavigationBarHidden(isHidden, animated: true)
    }

    private func updateShadowState(for viewController: UIViewController) {
        let shadowType: WalletBarShadowType

        if let designableBar = viewController as? WalletDesignableBar {
            shadowType = designableBar.shadowType
        } else {
            shadowType = .singleLine
        }

        switch shadowType {
        case .empty:
            navigationBar.shadowImage = UIImage()
        case .singleLine:
            if let navigationBarStyle = navigationBarStyle {
                navigationBar.shadowImage = UIImage.background(from: navigationBarStyle.shadowColor)
            }
        }
    }

    private func setupBackButtonItem(for viewController: UIViewController) {
        let backButtonItem = viewController.navigationItem.backBarButtonItem ?? UIBarButtonItem()
        backButtonItem.title = " "
        viewController.navigationItem.backBarButtonItem = backButtonItem
    }
}
