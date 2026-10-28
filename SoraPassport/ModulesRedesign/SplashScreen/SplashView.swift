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

class SplashView: UIView {
    private var bottomPart: UIView? {
        return self.viewWithTag(3)
    }

    private var mainLogo: UIView? {
        return self.viewWithTag(1)
    }

    private var textPart: UIView? {
        return self.viewWithTag(2)
    }

    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        if let mainLogo = (self.mainLogo as? UIImageView),
            let textPart = self.textPart,
            let bottomPart = self.bottomPart {
                let horizontal = mainLogo.centerXAnchor.constraint(equalTo: self.centerXAnchor, constant: -50)
                horizontal.isActive = true
                let vertical = mainLogo.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -2)
                vertical.isActive = true
                self.layoutIfNeeded()

                UIView.animateKeyframes(withDuration: animationDurationBase, delay: 0, options: .calculationModeLinear, animations: {

                    horizontal.constant += 50

                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5, animations: {
                        bottomPart.alpha = 1
                        textPart.alpha = 0
                        self.layoutIfNeeded()
                    })

                    mainLogo.widthAnchor.constraint(equalToConstant: 3000).isActive = true

                    UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5, animations: {
                        mainLogo.alpha = 0.01
                        self.layoutIfNeeded()
                    })
                },
                completion: { _ in
                    completion()
                })
        }
    }
}
