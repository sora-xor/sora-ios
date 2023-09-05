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

protocol KeyboardAdoptable: AnyObject {
    var keyboardHandler: KeyboardHandler? { get set }

    func updateWhileKeyboardFrameChanging(_ frame: CGRect)
}

extension KeyboardAdoptable {
    func setupKeyboardHandler() {
        guard keyboardHandler == nil else {
            return
        }

        keyboardHandler = KeyboardHandler(with: nil)
        keyboardHandler?.animateOnFrameChange = { [weak self] keyboardFrame in
            self?.updateWhileKeyboardFrameChanging(keyboardFrame)
        }
    }

    func clearKeyboardHandler() {
        keyboardHandler = nil
    }
}

protocol KeyboardViewAdoptable: KeyboardAdoptable {
    var targetBottomConstraint: NSLayoutConstraint? { get }
    var currentKeyboardFrame: CGRect? { get set }
    var shouldApplyKeyboardFrame: Bool { get }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat
}

private struct KeyboardViewAdoptableConstants {
    static var keyboardHandlerKey: String = "co.jp.fearless.keyboard.handler"
    static var keyboardFrameKey: String = "co.jp.fearless.keyboard.frame"
}

extension KeyboardViewAdoptable where Self: UIViewController {
    var keyboardHandler: KeyboardHandler? {
        get {
            return objc_getAssociatedObject(self, &KeyboardViewAdoptableConstants.keyboardHandlerKey)
                as? KeyboardHandler
        }

        set {
            objc_setAssociatedObject(self,
                                     &KeyboardViewAdoptableConstants.keyboardHandlerKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var currentKeyboardFrame: CGRect? {
        get {
            return objc_getAssociatedObject(self, &KeyboardViewAdoptableConstants.keyboardFrameKey)
                as? CGRect
        }

        set {
            objc_setAssociatedObject(self,
                                     &KeyboardViewAdoptableConstants.keyboardFrameKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var shouldApplyKeyboardFrame: Bool { true }

    func updateWhileKeyboardFrameChanging(_ keyboardFrame: CGRect) {}

    func setupKeyboardHandler() {
        guard keyboardHandler == nil else {
            return
        }

        let keyboardHandler = KeyboardHandler(with: nil)
        keyboardHandler.animateOnFrameChange = { [weak self] keyboardFrame in
            guard let strongSelf = self else {
                return
            }

            strongSelf.currentKeyboardFrame = keyboardFrame
            strongSelf.applyCurrentKeyboardFrame()
        }

        self.keyboardHandler = keyboardHandler
    }

    func applyCurrentKeyboardFrame() {
        guard let keyboardFrame = currentKeyboardFrame else {
            return
        }

        if let constraint = targetBottomConstraint {
            if shouldApplyKeyboardFrame {
                apply(keyboardFrame: keyboardFrame, to: constraint)

                view.layoutIfNeeded()
            }
        } else {
            updateWhileKeyboardFrameChanging(keyboardFrame)
        }
    }

    private func apply(keyboardFrame: CGRect, to constraint: NSLayoutConstraint) {
        let localKeyboardFrame = view.convert(keyboardFrame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY

        constraint.constant = -(bottomInset + offsetFromKeyboardWithInset(bottomInset))
    }
}
