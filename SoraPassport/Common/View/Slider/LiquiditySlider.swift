/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

class LiquiditySlider: UISlider {
  
      override func trackRect(forBounds bounds: CGRect) -> CGRect {
          let customBounds = CGRect(origin: bounds.origin, size: CGSize(width: bounds.size.width, height: 8.0))
          super.trackRect(forBounds: customBounds)
          return customBounds
      }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
          return true
      }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            let conversion = minimumValue + Float(location.x / bounds.width) * maximumValue
            setValue(conversion, animated: false)
            sendActions(for: .valueChanged)
        }
  }
