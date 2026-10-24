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
import SoraUI

protocol SecuredPresentable: AnyObject {
    func securePresentingView(animated: Bool)
    func unsecurePresentingView()
}

private struct SecuredPresentableConstants {
    static var securityViewKey = "co.jp.sora.secure.view"
}

private let securePresentation = UUID().uuidString

extension SecuredPresentable {
    private var securityView: UIView? {
        get {
            return objc_getAssociatedObject(securePresentation,
                                            &SecuredPresentableConstants.securityViewKey)
                as? UIView
        }

        set {
            objc_setAssociatedObject(securePresentation,
                                     &SecuredPresentableConstants.securityViewKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var presentationView: UIView? {
        return UIApplication.shared.keyWindow
    }
}

extension SecuredPresentable {
    func securePresentingView(animated: Bool) {
        guard securityView == nil, let presentationView = presentationView else {
            return
        }

        // Install synchronously before UIKit snapshots an inactive wallet.
        // Blur is insufficient protection for words and large PIN digits.
        let cover = UIView()
        cover.backgroundColor = WalletUX.page
        cover.accessibilityIdentifier = "wallet-private-app-switcher-cover"
        cover.translatesAutoresizingMaskIntoConstraints = false
        presentationView.addSubview(cover)
        let logo = UILabel()
        logo.text = "SORA"
        logo.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        logo.textColor = WalletUX.foreground
        logo.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(logo)
        NSLayoutConstraint.activate([
            cover.leadingAnchor.constraint(equalTo: presentationView.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: presentationView.trailingAnchor),
            cover.topAnchor.constraint(equalTo: presentationView.topAnchor),
            cover.bottomAnchor.constraint(equalTo: presentationView.bottomAnchor),
            logo.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
        ])
        presentationView.layoutIfNeeded()
        self.securityView = cover
    }

    func unsecurePresentingView() {
        securityView?.removeFromSuperview()
        securityView = nil
    }
}
