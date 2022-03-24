/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

class SplashView: UIView {
    private var bottomPart: UIView? {
        return self.viewWithTag(3)
    }

    private var mainLogo: UIView? {
        return self.viewWithTag(1)
    }

    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        if let mainLogo = (self.mainLogo as? UIImageView),
            let bottomPart = self.bottomPart {

            UIView.animateKeyframes(
                withDuration: animationDurationBase,
                delay: 0,
                options: .calculationModeLinear,
                animations: {

                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5, animations: {
                        bottomPart.alpha = 1
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
