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
import SoraUIKit
import SoraFoundation
import Combine

/// How the Wallet home's cards load: the rows are there at once, values fade
/// in as they arrive, and a small spinner stands where a total is not known
/// yet. No skeleton bars.
enum WalletHomeLoading {
    static let fadeDuration: CFTimeInterval = 0.25

    /// Cross-fades the next change of `view`'s content. An explicit layer
    /// transition also runs inside `UIView.performWithoutAnimation`, which
    /// the wallet's reloads use.
    static func fade(_ view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            view.layer.removeAnimation(forKey: "wallet.home.fade")
            return
        }
        let transition = CATransition()
        transition.type = .fade
        transition.duration = fadeDuration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.layer.add(transition, forKey: "wallet.home.fade")
    }

    static func makeSpinner() -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.color = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        spinner.accessibilityLabel = WalletUX.text("Loading…")
        return spinner
    }

    /// Shows `text` in a total's place, or the spinner while it is empty.
    static func applyTotal(_ text: String, to label: SoramitsuLabel, spinner: UIActivityIndicatorView,
                           animated: Bool = true) {
        let shown = (label.text ?? "").trimmingCharacters(in: .whitespaces)
        if !animated {
            label.layer.removeAnimation(forKey: "wallet.home.fade")
        } else if shown != text {
            fade(label)
        }
        label.sora.loadingPlaceholder.type = .none
        label.sora.cornerRadius = .zero
        label.sora.text = text.isEmpty ? " " : text
        if text.isEmpty {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }
}
