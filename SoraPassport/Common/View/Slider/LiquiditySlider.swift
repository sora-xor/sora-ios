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
