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
