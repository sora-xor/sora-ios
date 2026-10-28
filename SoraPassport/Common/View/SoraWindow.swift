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
#if F_DEV
import FLEX
#endif

final class SoraWindow: UIWindow {
    private struct Constants {
        static let statusHeight: CGFloat = 10.0
        static let appearanceAnimationDuration: TimeInterval = 0.2
        static let changeAnimationDuration: TimeInterval = 0.2
        static let dismissAnimationDuration: TimeInterval = 0.2
    }

    private var statusView: ApplicationStatusView?

    override func addSubview(_ view: UIView) {
        super.addSubview(view)

        bringStatusToFront()
    }

    override func bringSubviewToFront(_ view: UIView) {
        super.bringSubviewToFront(view)

        bringStatusToFront()
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        #if F_DEV
        if motion == .motionShake {
            FLEXManager.shared.showExplorer()
        }
        #endif
    }

    private func bringStatusToFront() {
        if let view = subviews.first(where: { $0 is ApplicationStatusView }) {
            super.bringSubviewToFront(view)
        }
    }

    private func apply(style: ApplicationStatusStyle, to view: ApplicationStatusView) {
        view.backgroundColor = style.backgroundColor
        view.titleLabel.textColor = style.titleColor
        view.titleLabel.font = style.titleFont
    }

    private func prepareStatusView() -> ApplicationStatusView {
        let topMargin = UIApplication.shared.statusBarFrame.size.height
        let width = UIApplication.shared.statusBarFrame.size.width
        let height = topMargin + Constants.statusHeight

        let origin = CGPoint(x: 0.0, y: -height)
        let frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
        let imageWithTitleView = ApplicationStatusView(frame: frame)
        imageWithTitleView.contentInsets = UIEdgeInsets(top: topMargin / 2.0, left: 0, bottom: 2, right: 0)

        return imageWithTitleView
    }

    private func changeStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool) {
        guard let statusView = statusView else {
            return
        }

        let closure = {
            if let title = title {
                statusView.titleLabel.text = title
            }

            if let style = style {
                self.apply(style: style, to: statusView)
            }
        }

        if animated {
            BlockViewAnimator(duration: Constants.changeAnimationDuration).animate(block: closure,
                                                                                   completionBlock: nil)
        } else {
            closure()
        }
    }
}

extension SoraWindow: ApplicationStatusPresentable {

    func presentAlert(alert: UIAlertController, animated: Bool) {
        if let topController = self.topController {
            if topController is UIAlertController {
                topController.dismiss(animated: true) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.topController?.present(alert, animated: true)
                    }
                }
            }
        }
        self.topController?.present(alert, animated: true)
    }

    func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool) {
        if statusView != nil {
            changeStatus(title: title, style: style, animated: animated)
            return
        }

        let statusView = prepareStatusView()
        statusView.titleLabel.text = title
        apply(style: style, to: statusView)

        self.statusView = statusView

        var newFrame = statusView.frame
        newFrame.origin = .zero

        addSubview(statusView)

        if animated {
            BlockViewAnimator(duration: Constants.appearanceAnimationDuration).animate(block: {
                statusView.frame = newFrame
            }, completionBlock: nil)
        } else {
            statusView.frame = newFrame
        }
    }

    func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool) {
        guard let statusView = statusView else {
            return
        }

        var animationDelay: TimeInterval = 0.0

        if title != nil || style != nil {
            changeStatus(title: title, style: style, animated: animated)

            if animated {
                animationDelay = Constants.changeAnimationDuration
            }
        }

        self.statusView = nil

        if animated {
            var newFrame = statusView.frame
            newFrame.origin.y = -newFrame.height

            BlockViewAnimator(duration: Constants.dismissAnimationDuration,
                              delay: 2 * animationDelay).animate(block: {
                statusView.frame = newFrame
            }, completionBlock: { _ in
                statusView.removeFromSuperview()
            })

        } else {
            statusView.removeFromSuperview()
        }
    }
}

extension UIWindow {
    var topController: UIViewController? {
        if var controller = self.rootViewController {
            while let presentedViewController = controller.presentedViewController {
                controller = presentedViewController
            }
            return controller
        }
        return nil
    }
}
