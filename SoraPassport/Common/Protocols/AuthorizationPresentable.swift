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

import UIKit
import SoraUIKit

typealias AuthorizationCompletionBlock = (Bool) -> Void

protocol AuthorizationPresentable: ScreenAuthorizationWireframeProtocol {
    @MainActor var authorizationPresentingController: UIViewController? { get }
    @MainActor func createAuthorizationView(cancellable: Bool) -> UIViewController?
    @MainActor func authorize(animated: Bool,
                   cancellable: Bool,
                   inView: UINavigationController?,
                   with completionBlock: @escaping AuthorizationCompletionBlock)
}

protocol AuthorizationAccessible {
    var isAuthorizing: Bool { get }
}

private let authorization = UUID().uuidString

private struct AuthorizationConstants {
    static var completionBlockKey: String = "co.jp.sora.auth.delegate"
    static var authorizationViewKey: String = "co.jp.sora.auth.view"
    static var inViewKey: String = "co.jp.sora.auth.inView"
}

extension AuthorizationPresentable {
    @MainActor var authorizationPresentingController: UIViewController? {
        UIApplication.shared.keyWindow?.rootViewController?.topModalViewController
    }

    @MainActor func createAuthorizationView(cancellable: Bool) -> UIViewController? {
        let authorizeView = PinViewFactory.createRedesignScreenAuthorizationView(with: self, cancellable: cancellable)
        let view = BlurViewController()
        view.modalPresentationStyle = .overFullScreen
        view.add(authorizeView?.controller)
        return view
    }
}

extension AuthorizationAccessible {
    var isAuthorizing: Bool {
        let view = objc_getAssociatedObject(authorization,
                                            &AuthorizationConstants.authorizationViewKey)
            as? UIViewController

        return view != nil
    }
}

extension AuthorizationPresentable {
    private var completionBlock: AuthorizationCompletionBlock? {
        get {
            return objc_getAssociatedObject(authorization, &AuthorizationConstants.completionBlockKey)
                as? AuthorizationCompletionBlock
        }

        set {
            objc_setAssociatedObject(authorization,
                                     &AuthorizationConstants.completionBlockKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var authorizationView: UIViewController? {
        get {
            return objc_getAssociatedObject(authorization, &AuthorizationConstants.authorizationViewKey)
                as? UIViewController
        }

        set {
            objc_setAssociatedObject(authorization,
                                     &AuthorizationConstants.authorizationViewKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var inView: UINavigationController? {
        get {
            return objc_getAssociatedObject(authorization, &AuthorizationConstants.inViewKey)
                as? UINavigationController
        }

        set {
            objc_setAssociatedObject(authorization,
                                     &AuthorizationConstants.inViewKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var isAuthorizing: Bool {
        return authorizationView != nil
    }
}

extension AuthorizationPresentable {
    @MainActor func authorize(animated: Bool, with completionBlock: @escaping AuthorizationCompletionBlock) {
        authorize(animated: animated, cancellable: false, inView: nil, with: completionBlock)
    }

    @MainActor func authorize(animated: Bool,
                   cancellable: Bool,
                   inView: UINavigationController?,
                   with completionBlock: @escaping AuthorizationCompletionBlock) {

        guard !isAuthorizing else {
            completionBlock(false)
            return
        }
        guard let presentingController = authorizationPresentingController else {
            completionBlock(false)
            return
        }
        let view = createAuthorizationView(cancellable: cancellable)

        guard let authorizationView = view else {
            completionBlock(false)
            return
        }

        self.completionBlock = completionBlock
        self.authorizationView = view
        self.inView = inView

        authorizationView.modalTransitionStyle = .crossDissolve
        authorizationView.modalPresentationStyle = .fullScreen

        if let inView = inView {
            authorizationView.navigationItem.hidesBackButton = true
            authorizationView.hidesBottomBarWhenPushed = true
            inView.pushViewController(authorizationView, animated: animated)
        } else {
            presentingController.present(authorizationView, animated: animated, completion: nil)
        }
    }

    func removeExistingAuthViewIfPresented(completion: @escaping ()->()) {
        if let authorizationView = authorizationView {
            let previousCompletion = completionBlock
            dismissAuthorizationView(authorizationView, completionBlock: { result in
                previousCompletion?(result)
                completion()
            }, result: false)
        } else {
            completion()
        }
    }
}

extension AuthorizationPresentable {
    func showAuthorizationCompletion(with result: Bool) {
        guard let completionBlock = completionBlock else {
            return
        }

        self.completionBlock = nil

        guard let authorizationView = authorizationView else {
            return
        }

        dismissAuthorizationView(authorizationView, completionBlock: completionBlock, result: result)
    }

    func dismissAuthorizationView(_ authorizationView: UIViewController, completionBlock: AuthorizationCompletionBlock?, result: Bool) {
        let navigation = self.inView
        self.completionBlock = nil
        self.authorizationView = nil
        self.inView = nil

        if let navigation {
            navigation.setViewControllers(
                navigation.viewControllers.filter { $0 !== authorizationView },
                animated: false
            )
            completionBlock?(result)
        } else if let presenter = authorizationView.presentingViewController {
            presenter.dismiss(animated: true) {
                completionBlock?(result)
            }
        } else {
            completionBlock?(result)
        }
    }
}
