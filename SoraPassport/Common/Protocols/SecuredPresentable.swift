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
