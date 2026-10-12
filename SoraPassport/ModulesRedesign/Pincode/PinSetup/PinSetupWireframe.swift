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
import SoraFoundation

class PinSetupWireframe: PinSetupWireframeProtocol, AlertPresentable, ErrorPresentable {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    let localizationManager: LocalizationManagerProtocol
    private let mainViewFactory: @MainActor () throws -> UIViewController
    private var isOpeningWallet = false

    init(localizationManager: LocalizationManagerProtocol,
         mainViewFactory: @escaping @MainActor () throws -> UIViewController = {
             try MainTabBarViewFactory.createViewOrThrow().controller
         }) {
        self.localizationManager = localizationManager
        self.mainViewFactory = mainViewFactory
    }

    func dismiss(from view: PinSetupViewProtocol?) {
        if let presentingViewController = view?.controller.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        }
        if let navigationController = view?.controller.navigationController {
            navigationController.popViewController(animated: true)
        }
    }

    @MainActor
    func showMain(from view: PinSetupViewProtocol?) {
        guard !isOpeningWallet else { return }
        isOpeningWallet = true
        let window = view?.controller.view.window ?? (UIApplication.shared.delegate?.window ?? nil)
        let animator = rootAnimator
        let transition: (UIViewController) -> Void = { [weak window] controller in
            if let window {
                animator.animateTransition(to: controller, in: window)
            } else {
                animator.animateTransition(to: controller)
            }
        }
        let opening = WalletOpeningViewController(
            makeWallet: mainViewFactory,
            refresh: { ChainRegistryFacade.sharedRegistry.syncUp() },
            makeNodes: { NodesViewFactory.createView()?.controller },
            recheckWallet: { [weak window] in
                guard let window = window as? SoraWindow else { return }
                SplashPresenterFactory.createSplashPresenter(with: window)
            },
            opened: transition
        )
        transition(UINavigationController(rootViewController: opening))
    }

    public func showSignup(from view: PinSetupViewProtocol?) {
    }

    func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void) {

        let languages = localizationManager.preferredLocalizations

        let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.pincodeChangeSuccess(preferredLanguages: languages))

        view?.controller.present(success, animated: true, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                completionBlock()
            }
        })
    }
}

/// Authentication has succeeded, but local chain/asset subscriptions can still
/// be starting. Retry their construction without asking for the PIN again or
/// coupling the app's navigation to a successful remote request.
@MainActor
final class WalletOpeningViewController: UIViewController {
    private let makeWallet: () throws -> UIViewController
    private let refresh: () -> Void
    private let makeNodes: () -> UIViewController?
    private let recheckWallet: () -> Void
    private let opened: (UIViewController) -> Void
    private let retryInterval: TimeInterval
    private let maximumAttempts: Int
    private var retryTask: Task<Void, Never>?
    private var attempts = 0
    private var didOpen = false
    private let status = UILabel()
    private let progress = UIActivityIndicatorView(style: .large)
    private let retryButton = UIButton(type: .system)
    private let nodesButton = UIButton(type: .system)
    private let recheckButton = UIButton(type: .system)

    init(makeWallet: @escaping () throws -> UIViewController,
         refresh: @escaping () -> Void,
         makeNodes: @escaping () -> UIViewController?,
         recheckWallet: @escaping () -> Void,
         opened: @escaping (UIViewController) -> Void,
         retryInterval: TimeInterval = 1,
         maximumAttempts: Int = 10) {
        self.makeWallet = makeWallet
        self.refresh = refresh
        self.makeNodes = makeNodes
        self.recheckWallet = recheckWallet
        self.opened = opened
        self.retryInterval = retryInterval
        self.maximumAttempts = maximumAttempts
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    deinit { retryTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WalletUX.page
        title = WalletUX.text("Opening wallet")
        status.font = .preferredFont(forTextStyle: .body)
        status.textColor = WalletUX.foreground
        status.numberOfLines = 0
        status.textAlignment = .center
        status.accessibilityIdentifier = "wallet-opening-status"
        progress.hidesWhenStopped = true
        for (button, title, identifier, action) in [
            (retryButton, "Try again", "wallet-opening-retry", #selector(retry)),
            (nodesButton, "Change node", "wallet-opening-nodes", #selector(selectNode)),
            (recheckButton, "Check wallet again", "wallet-opening-recheck", #selector(recheck))
        ] {
            button.setTitle(WalletUX.text(title), for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            button.accessibilityIdentifier = identifier
            button.addTarget(self, action: action, for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        let stack = UIStackView(arrangedSubviews: [progress, status, retryButton, nodesButton, recheckButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        retry()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        retryTask?.cancel()
        retryTask = nil
    }

    @objc private func retry() {
        guard !didOpen else { return }
        retryTask?.cancel()
        retryTask = nil
        attempts = 0
        refresh()
        attemptOpen()
    }

    private func attemptOpen() {
        guard !didOpen else { return }
        attempts += 1
        do {
            let wallet = try makeWallet()
            didOpen = true
            retryTask?.cancel()
            retryTask = nil
            progress.stopAnimating()
            opened(wallet)
        } catch {
            let reason = (error as? WalletOpeningError) ?? .contextNotReady
            // Log only a fixed stage code, never account or remote error data.
            Logger.shared.warning("Wallet opening deferred: \(reason.rawValue); attempt=\(attempts)")
            let recoveryRequired = reason == .recoveryRequired || reason == .accountNotReady
            recheckButton.isHidden = !recoveryRequired
            nodesButton.isHidden = recoveryRequired
            retryButton.isHidden = recoveryRequired
            nodesButton.isEnabled = !recoveryRequired
            let shouldRetry = !recoveryRequired && attempts < maximumAttempts
            retryButton.isEnabled = !shouldRetry
            if shouldRetry {
                status.text = WalletUX.text("Preparing wallet services…")
                progress.startAnimating()
                retryTask = Task { [weak self, retryInterval] in
                    do { try await Task.sleep(nanoseconds: UInt64(max(0, retryInterval) * 1_000_000_000)) }
                    catch { return }
                    guard !Task.isCancelled else { return }
                    self?.attemptOpen()
                }
            } else {
                progress.stopAnimating()
                status.text = WalletUX.text(recoveryRequired
                    ? "Wallet verification needs attention. Check your saved wallet again."
                    : "Wallet services are not ready. Try again or choose another node.")
            }
        }
    }

    @objc private func selectNode() {
        guard navigationController?.topViewController === self else { return }
        retryTask?.cancel()
        retryTask = nil
        progress.stopAnimating()
        retryButton.isEnabled = true
        guard let nodes = makeNodes() else {
            status.text = WalletUX.text("Node settings are still loading. Try again.")
            return
        }
        navigationController?.pushViewController(nodes, animated: true)
    }

    @objc private func recheck() {
        retryTask?.cancel()
        retryTask = nil
        recheckWallet()
    }
}
