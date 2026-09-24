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

/// Locks the existing presentation in place. Authentication must never replace
/// an in-progress import/recovery root or attempt to construct an unverified wallet.
final class SecurityLayerWireframe: NSObject, SecurityLayerWireframProtocol, ScreenAuthorizationWireframeProtocol, SecuredPresentable {
    var logger: LoggerProtocol?
    private let windowProvider: () -> UIWindow?
    private let pinFactory: (ScreenAuthorizationWireframeProtocol) -> PinSetupViewProtocol?
    private weak var applicationWindow: UIWindow?
    private(set) var authorizationWindow: UIWindow?

    init(windowProvider: @escaping () -> UIWindow? = {
             // Loading and authentication windows can temporarily be key. The
             // app delegate owns the flow that must survive reauthentication.
             (UIApplication.shared.delegate as? AppDelegate)?.window ??
                 UIApplication.shared.windows.first { $0 is SoraWindow }
         },
         pinFactory: @escaping (ScreenAuthorizationWireframeProtocol) -> PinSetupViewProtocol? = {
             PinViewFactory.createRedesignScreenAuthorizationView(with: $0, cancellable: false)
         }) {
        self.windowProvider = windowProvider
        self.pinFactory = pinFactory
        super.init()
    }

    private func containsRootPincode(_ controller: UIViewController) -> Bool {
        controller is PinSetupViewProtocol || controller.children.contains(where: containsRootPincode)
    }

    func showSecuringOverlay() {
        if authorizationWindow != nil { return }
        guard let root = windowProvider()?.rootViewController,
              !containsRootPincode(root) else { return }
        securePresentingView(animated: true)
    }

    func hideSecuringOverlay() {
        unsecurePresentingView()
    }

    func showAuthorization() {
        guard authorizationWindow == nil, let window = windowProvider(),
              let root = window.rootViewController, !containsRootPincode(root) else { return }
        let lockWindow: UIWindow
        if let scene = window.windowScene {
            lockWindow = UIWindow(windowScene: scene)
        } else {
            lockWindow = UIWindow(frame: window.bounds)
        }
        lockWindow.frame = window.frame
        lockWindow.windowLevel = UIWindow.Level(rawValue: max(window.windowLevel.rawValue, UIWindow.Level.alert.rawValue) + 1)
        applicationWindow = window
        authorizationWindow = lockWindow
        installPincode(on: lockWindow)
        lockWindow.makeKeyAndVisible()
    }

    private func installPincode(on window: UIWindow) {
        // A separate opaque window permits an outstanding Google callback to
        // present its result on the original controller, covered until PIN succeeds.
        let container = UIViewController()
        container.view.backgroundColor = .systemBackground
        container.view.accessibilityIdentifier = "wallet-resume-authorization"
        window.rootViewController = container
        if let pin = pinFactory(self) {
            container.addChild(pin.controller)
            pin.controller.view.translatesAutoresizingMaskIntoConstraints = false
            container.view.addSubview(pin.controller.view)
            NSLayoutConstraint.activate([
                pin.controller.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
                pin.controller.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
                pin.controller.view.topAnchor.constraint(equalTo: container.view.topAnchor),
                pin.controller.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
            ])
            pin.controller.didMove(toParent: container)
        } else {
            let retry = UIButton(type: .system)
            retry.setTitle("PIN verification unavailable. Try again", for: .normal)
            retry.translatesAutoresizingMaskIntoConstraints = false
            retry.addTarget(self, action: #selector(retryAuthorization), for: .touchUpInside)
            container.view.addSubview(retry)
            NSLayoutConstraint.activate([
                retry.centerXAnchor.constraint(equalTo: container.view.centerXAnchor),
                retry.centerYAnchor.constraint(equalTo: container.view.centerYAnchor)
            ])
        }
    }

    @objc private func retryAuthorization() {
        guard let window = authorizationWindow else { return }
        installPincode(on: window)
    }

    func showAuthorizationCompletion(with result: Bool) {
        guard let lockWindow = authorizationWindow else { return }
        guard result else {
            // Failed/canceled authentication never uncovers or discards the
            // original wallet flow. A fresh interactor allows a safe retry.
            logger?.error("Resume PIN authorization failed")
            installPincode(on: lockWindow)
            let message = UIAlertController(title: "PIN verification unavailable",
                message: "Your wallet screen is still protected. Try entering your PIN again.", preferredStyle: .alert)
            message.addAction(UIAlertAction(title: WalletUX.text("Try again"), style: .default))
            lockWindow.rootViewController?.present(message, animated: true)
            return
        }
        lockWindow.isHidden = true
        lockWindow.rootViewController = nil
        authorizationWindow = nil
        applicationWindow?.makeKeyAndVisible()
        applicationWindow = nil
    }
}
