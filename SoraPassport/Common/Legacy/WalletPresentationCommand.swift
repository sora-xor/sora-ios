//
//  WalletPresentationCommand.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

public enum WalletPresentationStyle {
    case push(hidesBottomBar: Bool)
    case modal(inNavigation: Bool)
    case setRoot
}

public protocol WalletPresentationCommandProtocol: WalletCommandProtocol {
    var presentationStyle: WalletPresentationStyle { get set }
    var animated: Bool { get set }
    var completionBlock: (() -> Void)? { get set }
}

extension WalletPresentationCommandProtocol {
    func present(view: UIViewController, in navigation: NavigationProtocol,
                 animated: Bool, completion: (() -> Void)? = nil) {
        switch presentationStyle {
        case .push(let hidesBottomBar):
            view.hidesBottomBarWhenPushed = hidesBottomBar
            navigation.push(view, animated: animated)
        case .modal(let inNavigation):
            navigation.present(view, inNavigationController: inNavigation, animated: animated, completion: completion)
        case .setRoot:
            navigation.set(view, animated: animated)
        }
    }
}
