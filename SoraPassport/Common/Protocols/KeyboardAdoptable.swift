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
        let intersection = view.bounds.intersection(localKeyboardFrame)
        let bottomInset = intersection.isNull || intersection.isEmpty ? 0 : intersection.height

        constraint.constant = -(bottomInset + offsetFromKeyboardWithInset(bottomInset))
    }
}
