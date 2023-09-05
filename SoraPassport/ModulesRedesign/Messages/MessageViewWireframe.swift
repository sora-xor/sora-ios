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

public class MessageViewWireframe: NSObject, MessageViewWireframeProtocol {
    public static var animationDuration: Double = 0.25
    public static var presentationDuration: Double = 2.0

    public static let shared = MessageViewWireframe()

    private override init() {}

    public func show(message: SoraMessageProtocol, on window: UIWindow, animated: Bool) {
        cancelScheduledHidding(on: window)

        defer {
            window.windowLevel = UIWindow.Level.statusBar + 1
        }

        if let messageView = findMessageView(on: window) {
            messageView.layer.removeAllAnimations()
            messageView.set(message: message)
            messageView.frame = calculateVisibleFrame(on: window, for: messageView)
        } else {
            guard let messageView = MessageViewFactory().createMessageView() as? MessageView else {
                return
            }

            messageView.set(message: message)

            let startFrame = calculateHiddenFrame(on: window, for: messageView)
            let finalFrame = calculateVisibleFrame(on: window, for: messageView)

            messageView.frame = startFrame
            window.addSubview(messageView)

            if animated {
                UIView.animate(withDuration: type(of: self).animationDuration) {
                    messageView.frame = finalFrame
                }
            } else {
                messageView.frame = finalFrame
            }
        }

        scheduleHidding(on: window)
    }

    public func hide(on window: UIWindow, animated: Bool) {
        cancelScheduledHidding(on: window)

        defer {
            window.windowLevel = UIWindow.Level.statusBar - 1
        }

        guard let messageView = findMessageView(on: window) else {
            return
        }

        guard animated else {
            messageView.removeFromSuperview()
            return
        }

        UIView.animate(
            withDuration: type(of: self).animationDuration,
            animations: {
                messageView.frame = self.calculateHiddenFrame(on: window, for: messageView)
        },
            completion: { completed in
                if completed {
                    messageView.removeFromSuperview()
                }

        })
    }

    // MARK: Scheduled Hidding

    @objc private func onShowTimeout(window: UIWindow) {
        hide(on: window, animated: true)
    }

    private func scheduleHidding(on window: UIWindow) {
        perform(#selector(onShowTimeout(window:)), with: window, afterDelay: type(of: self).presentationDuration)
    }

    private func cancelScheduledHidding(on window: UIWindow) {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(onShowTimeout(window:)),
                                               object: window)
    }

    // MARK: Message View Layout

    private func findMessageView(on window: UIWindow) -> MessageView? {
        for subview in window.subviews {
            if let messageView = subview as? MessageView {
                return messageView
            }
        }

        return nil
    }

    private func calculateVisibleFrame(on window: UIWindow, for messageView: MessageView) -> CGRect {
        let contentHeight = messageView.intrinsicContentSize.height
        return CGRect(x: 0.0, y: 0.0, width: window.frame.width, height: contentHeight)
    }

    private func calculateHiddenFrame(on window: UIWindow, for messageView: MessageView) -> CGRect {
        let contentHeight = messageView.intrinsicContentSize.height
        return CGRect(x: 0.0, y: -contentHeight, width: window.frame.width, height: contentHeight)
    }
}
