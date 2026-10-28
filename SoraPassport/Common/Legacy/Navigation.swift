//
//  Navigation.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

protocol NavigationProtocol {
    
    var navigationController: WalletNavigationController? { get }
    
    func set(_ viewController: UIViewController, animated: Bool)
    func push(_ controller: UIViewController, animated: Bool)
    func pop(animated: Bool)
    func popToRoot(animated: Bool)
    func dismiss(animated: Bool, completion: (() -> Void)?)
    func present(_ controller: UIViewController,
                 inNavigationController: Bool,
                 animated: Bool,
                 completion: (() -> Void)?)
    
}


extension NavigationProtocol {
    
    func set(_ viewController: UIViewController) {
        set(viewController, animated: true)
    }

    func push(_ controller: UIViewController) {
        push(controller, animated: true)
    }

    func pop() {
        pop(animated: true)
    }

    func popToRoot() {
        popToRoot(animated: true)
    }

    func dismiss() {
        dismiss(animated: true, completion: nil)
    }

    func dismiss(animated: Bool) {
        dismiss(animated: animated, completion: nil)
    }

    func present(_ controller: UIViewController, inNavigationController: Bool) {
        present(controller, inNavigationController: inNavigationController, animated: true, completion: nil)
    }

    func present(_ controller: UIViewController, inNavigationController: Bool, animated: Bool) {
        present(controller, inNavigationController: inNavigationController, animated: animated, completion: nil)
    }
    
}
