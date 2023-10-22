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

import Foundation
import SoraUI

final class ShakeAnimator: ViewAnimatorProtocol {
    let duration: TimeInterval
    let delay: TimeInterval
    let dumpingFactor: CGFloat
    let initialVelocity: CGFloat
    let initialAmplitude: CGFloat
    let options: UIView.AnimationOptions

    init(duration: TimeInterval = 0.25,
         delay: TimeInterval = 0.0,
         dumpingFactor: CGFloat = 0.4,
         initialVelocity: CGFloat = 1.0,
         initialAmplitude: CGFloat = 20.0,
         options: UIView.AnimationOptions = []) {
        self.duration = duration
        self.delay = delay
        self.dumpingFactor = dumpingFactor
        self.initialVelocity = initialVelocity
        self.initialAmplitude = initialAmplitude
        self.options = options
    }

    func animate(view: UIView, completionBlock: ((Bool) -> Void)?) {
        view.transform = CGAffineTransform(translationX: initialAmplitude, y: 0)

        let block = {
            view.transform = CGAffineTransform.identity
        }

        UIView.animate(withDuration: duration,
                       delay: delay,
                       usingSpringWithDamping: dumpingFactor,
                       initialSpringVelocity: initialVelocity,
                       options: options,
                       animations: block,
                       completion: completionBlock)
    }
}
