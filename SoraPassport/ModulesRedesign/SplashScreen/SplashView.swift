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
