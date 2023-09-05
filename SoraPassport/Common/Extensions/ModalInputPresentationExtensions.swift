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

import SoraUI

extension ModalSheetPresentationHeaderStyle {

    static var modalHeaderStyle: ModalSheetPresentationHeaderStyle {
        let indicatorColor = UIColor(white: 208.0 / 255.0, alpha: 1.0)
        return ModalSheetPresentationHeaderStyle(preferredHeight: 20.0,
                                                 backgroundColor: .white,
                                                 cornerRadius: 10.0,
                                                 indicatorVerticalOffset: 3.0,
                                                 indicatorSize: CGSize(width: 35, height: 5.0),
                                                 indicatorColor: indicatorColor)
    }

    static var neu: ModalSheetPresentationHeaderStyle {
        return ModalSheetPresentationHeaderStyle(preferredHeight: 0,
                                                 backgroundColor: R.color.neumorphism.base()!,
                                                 cornerRadius: 40,
                                                 indicatorVerticalOffset: 4,
                                                 indicatorSize: CGSize(width: 64, height: 4),
                                                 indicatorColor: R.color.neumorphism.separator()!)
    }

}

extension ModalSheetPresentationConfiguration {
    static var sora: ModalSheetPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(duration: 0.25,
                                                   delay: 0.0,
                                                   options: [.curveEaseOut])
        let dismissalAnimator = BlockViewAnimator(duration: 0.25,
                                                  delay: 0.0,
                                                  options: [.curveLinear])

        let style = ModalSheetPresentationStyle(backdropColor: UIColor.white.withAlphaComponent(0.19),
                                                headerStyle: ModalSheetPresentationHeaderStyle.modalHeaderStyle)

        return ModalSheetPresentationConfiguration(contentAppearanceAnimator: appearanceAnimator,
                                                                contentDissmisalAnimator: dismissalAnimator,
                                                                style: style,
                                                                extendUnderSafeArea: true,
                                                                dismissFinishSpeedFactor: 0.6,
                                                                dismissCancelSpeedFactor: 0.6)
    }
    static var neu: ModalSheetPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(duration: 0.25,
                                                   delay: 0.0,
                                                   options: [.curveEaseOut])
        let dismissalAnimator = BlockViewAnimator(duration: 0.25,
                                                  delay: 0.0,
                                                  options: [.curveLinear])

        let style = ModalSheetPresentationStyle(backdropColor: R.color.neumorphism.polkaswapDim()!,
                                                headerStyle: .neu)

        return ModalSheetPresentationConfiguration(contentAppearanceAnimator: appearanceAnimator,
                                                                contentDissmisalAnimator: dismissalAnimator,
                                                                style: style,
                                                                extendUnderSafeArea: true,
                                                                dismissFinishSpeedFactor: 0.6,
                                                                dismissCancelSpeedFactor: 0.6)
    }
}
