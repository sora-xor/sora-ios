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
import SoraFoundation

public enum ActionPresentationConstants {
    public static let transitionDuration: TimeInterval = 0.25
    public static let appearanceAnimationOptions: UIView.AnimationOptions = [.curveEaseOut]
    public static let dissmisalAnimationOptions: UIView.AnimationOptions = [.curveEaseIn]
}

public class ActionPresentationFactory: NSObject {}

extension ActionPresentationFactory: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ActionPresentationAppearanceAnimator()
    }

    public func animationController(forDismissed dismissed: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
            return ActionPresentationDismissAnimator()
    }

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                       source: UIViewController) -> UIPresentationController? {
        let inputPresentationController = ActionPresentationController(presentedViewController: presented,
                                                                       presenting: presenting,
                                                                       keyboardHandler: KeyboardHandler())
        return inputPresentationController
    }
}

public final class ActionPresentationAppearanceAnimator: NSObject {}

extension ActionPresentationAppearanceAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return ActionPresentationConstants.transitionDuration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .to) else {
            return
        }

        let finalFrame = transitionContext.finalFrame(for: presentedController)
        var initialFrame = finalFrame
        initialFrame.origin.y += finalFrame.size.height

        presentedController.view.frame = initialFrame
        transitionContext.containerView.addSubview(presentedController.view)

        let animationBlock: () -> Void = {
            presentedController.view.frame = finalFrame
        }

        let completionBlock: (Bool) -> Void = { finished in
            transitionContext.completeTransition(finished)
        }

        UIView.animate(withDuration: ActionPresentationConstants.transitionDuration,
                       delay: 0.0,
                       options: ActionPresentationConstants.appearanceAnimationOptions,
                       animations: animationBlock,
                       completion: completionBlock)
    }
}

public final class ActionPresentationDismissAnimator: NSObject {}

extension ActionPresentationDismissAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return ActionPresentationConstants.transitionDuration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .from) else {
            return
        }

        let initialFrame = presentedController.view.frame
        var finalFrame = initialFrame
        finalFrame.origin.y = transitionContext.containerView.frame.maxY

        let animationBlock: () -> Void = {
            presentedController.view.frame = finalFrame
        }

        let completionBlock: (Bool) -> Void = { finished in
            presentedController.view.removeFromSuperview()
            transitionContext.completeTransition(finished)
        }

        UIView.animate(withDuration: ActionPresentationConstants.transitionDuration,
                       delay: 0.0,
                       options: ActionPresentationConstants.dissmisalAnimationOptions,
                       animations: animationBlock,
                       completion: completionBlock)
    }
}
