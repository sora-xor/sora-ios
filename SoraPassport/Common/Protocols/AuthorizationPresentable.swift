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

import UIKit
import SoraUIKit

typealias AuthorizationCompletionBlock = (Bool) -> Void

protocol AuthorizationPresentable: ScreenAuthorizationWireframeProtocol {
    func authorize(animated: Bool,
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

extension AuthorizationAccessible {
    var isAuthorizing: Bool {
        let view = objc_getAssociatedObject(authorization,
                                            &AuthorizationConstants.authorizationViewKey)
            as? PinSetupViewProtocol

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
    func authorize(animated: Bool, with completionBlock: @escaping AuthorizationCompletionBlock) {
        authorize(animated: animated, cancellable: false, inView: nil, with: completionBlock)
    }

    func authorize(animated: Bool,
                   cancellable: Bool,
                   inView: UINavigationController?,
                   with completionBlock: @escaping AuthorizationCompletionBlock) {

        guard let presentingController = UIApplication.shared.keyWindow?
            .rootViewController?.topModalViewController else {
            return
        }

        let view: UIViewController?

        let auhorizeView = PinViewFactory.createRedesignScreenAuthorizationView(with: self, cancellable: cancellable)
        view = BlurViewController()
        view?.modalPresentationStyle = .overFullScreen
        view?.add(auhorizeView?.controller)
        
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
            dismissAuthorizationView(authorizationView, completionBlock: completionBlock, result: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
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

    func dismissAuthorizationView(_ authorizationView:  UIViewController, completionBlock: AuthorizationCompletionBlock?, result: Bool) {
        if let inView = self.inView {

            completionBlock?(result)
            let controllerToRemove = inView.viewControllers.remove(at: 1)
            self.authorizationView?.dismiss(animated: false)

            self.authorizationView = nil
            self.inView = nil

        } else {
            authorizationView.presentingViewController?.dismiss(animated: true) {
                self.authorizationView = nil
                completionBlock?(result)
            }
        }
    }
}
