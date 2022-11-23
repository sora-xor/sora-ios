/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
extension NeuPinView {

    @IBInspectable
    private var _numpadBackspaceIcon: UIImage? {
        get { return numpad.backspaceIcon }
        set(newValue) {
            numpad.backspaceIcon = newValue
        }
    }

    @IBInspectable
    private var _numpadAccessoryIcon: UIImage? {
        get { return numpad.accessoryIcon }
        set(newValue) {
            numpad.accessoryIcon = newValue
        }
    }
}
