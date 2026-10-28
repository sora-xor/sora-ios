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
import SoraUI

protocol SecuredPresentable: AnyObject {
    func securePresentingView(animated: Bool)
    func unsecurePresentingView()
}

private struct SecuredPresentableConstants {
    static var securityViewKey = "co.jp.sora.secure.view"
}

private let securePresentation = UUID().uuidString

extension SecuredPresentable {
    private var securityView: UIView? {
        get {
            return objc_getAssociatedObject(securePresentation,
                                            &SecuredPresentableConstants.securityViewKey)
                as? UIView
        }

        set {
            objc_setAssociatedObject(securePresentation,
                                     &SecuredPresentableConstants.securityViewKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var presentationView: UIView? {
        return UIApplication.shared.keyWindow
    }
}

extension SecuredPresentable {
    func securePresentingView(animated: Bool) {
        guard securityView == nil, let presentationView = presentationView else {
            return
        }

        let blurView = UIVisualEffectView()
        blurView.effect = UIBlurEffect(style: .regular)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        presentationView.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: presentationView.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: presentationView.widthAnchor),
            blurView.centerXAnchor.constraint(equalTo: presentationView.centerXAnchor),
            blurView.centerYAnchor.constraint(equalTo: presentationView.centerYAnchor)
            ])

        self.securityView = blurView

        if animated {
            let transitionAnimator = TransitionAnimator(type: .reveal)
            transitionAnimator.animate(view: blurView, completionBlock: nil)
        }
    }

    func unsecurePresentingView() {
        securityView?.removeFromSuperview()
        securityView = nil
    }
}
