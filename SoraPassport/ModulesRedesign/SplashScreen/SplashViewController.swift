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

import Foundation
import UIKit
import SoraUIKit
import SnapKit

class SplashViewController: UIViewController, SplashViewProtocol {
    
    var presenter: SplashPresenter!
    private var storageRetryView: UIView?
    private var isWaitingForStorage = false
    private enum AnimationPhase { case notStarted, intro, holding, outro, finished }
    private var animationPhase: AnimationPhase = .notStarted
    private var startupCompletion: (() -> Void)?
    
    /// The launch flight: through the gate of heaven to the planet. It stops in front of the last seal
    /// until the wallet is ready, then goes through as day breaks into the first screen. A phone that can
    /// fly the traced scene gets it; one saving power gets the same flight as line figures.
    private(set) var flight: (UIView & SacredFlight)?
    private let flightHost = UIView()
    /// How long the traced scene's shader may take to build before the plain flight goes instead.
    static var sceneWait: TimeInterval = 0.6

    /// Reduced effects and Reduce Motion show where the flight rests, and nothing moves.
    private var showsMotion: Bool { !(FxPolicy.reduceEffects || FxPolicy.current.reduceMotion) }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // The launch scene fills the screen; nothing of it belongs in a bar down the side.
    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }

    private func install(_ view: UIView & SacredFlight) {
        flight?.removeFromSuperview()
        // The flight measures its scene from its size, so the screen is laid out first.
        self.view.layoutIfNeeded()
        view.frame = flightHost.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        flightHost.addSubview(view)
        flight = view
    }

    /// Picks the flight and starts it. The traced scene is used when its shader is built in time.
    private func startFlight() {
        guard SacredTenmonView.canFly else {
            flyIntro(SacredGateView())
            return
        }
        let scene = SacredTenmonView()
        scene.page = SoramitsuThemeType.light.palette.color(.bgPage)
        #if F_RELEASE
        let wait = Self.sceneWait
        #else
        // `-SacredSceneWait 8` on a slow simulator, to film the traced scene there.
        let wait = max(Self.sceneWait, UserDefaults.standard.double(forKey: "SacredSceneWait"))
        #endif
        SacredTenmonPipeline.shared.whenReady(within: wait) { [weak self] ready in
            guard let self, self.animationPhase == .intro, self.flight == nil else { return }
            let chosen: UIView & SacredFlight = ready ? scene : SacredGateView()
            self.flyIntro(chosen)
        }
    }

    private func flyIntro(_ view: UIView & SacredFlight) {
        install(view)
        view.playIntro { [weak self] in
            self?.introCompleted()
        }
    }

    private var messageLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.launchScreenLoadingTitle(preferredLanguages: .currentLocale)
        label.sora.font = FontType.textS
        // Pale, for the dark launch page.
        label.sora.textColor = .custom(uiColor: SacredInk.nightLine.withAlphaComponent(0.78))
        label.sora.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var loaderView: UIActivityIndicatorView = {
        let loaderView = UIActivityIndicatorView(style: .large)
        loaderView.translatesAutoresizingMaskIntoConstraints = false
        loaderView.color = SacredInk.nightLine.withAlphaComponent(0.78)
        return loaderView
    }()
    
    private var containerView: SoramitsuView = {
        let containerView = SoramitsuView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.sora.isHidden = true
        return containerView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // The launch screen's own dark: the flight rises out of it.
        view.backgroundColor = SacredInk.night
        setupHierarchy()
        setupLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard animationPhase == .notStarted, !isWaitingForStorage else { return }
        animationPhase = .intro
        if showsMotion {
            startFlight()
        } else {
            let still = SacredGateView()
            install(still)
            still.showArrival()
            introCompleted()
        }
    }

    private func introCompleted() {
        guard animationPhase == .intro else { return }
        animationPhase = .holding
        if startupCompletion != nil {
            finishAnimationIfReady()
        } else {
            presenter?.showIsLoading(after: 5.0) { [weak self] in
                guard self?.animationPhase == .holding else { return }
                self?.showLoader()
            }
        }
    }
    
    private func setupHierarchy() {
        view.addSubview(flightHost)
        view.addSubview(containerView)
        
        containerView.addSubview(messageLabel)
        containerView.addSubview(loaderView)
    }
    
    private func setupLayout() {
        let containerViewBottomOffset: CGFloat = 76
        let spinnerViewTopOffset: CGFloat = 24
        
        flightHost.isUserInteractionEnabled = false
        flightHost.snp.makeConstraints { make in
            make.center.width.height.equalTo(view)
        }
        
        containerView.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-containerViewBottomOffset)
            make.leading.equalTo(messageLabel)
            make.centerX.equalTo(view)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(containerView)
        }
        
        loaderView.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(spinnerViewTopOffset)
            make.centerX.bottom.equalTo(containerView)
        }
    }
    
    private func showLoader() {
        guard !isWaitingForStorage else { return }
        containerView.sora.isHidden = false
        loaderView.startAnimating()
    }
    
    private func hideLoader() {
        containerView.sora.isHidden = true
        loaderView.stopAnimating()
    }
    
    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        guard animationPhase != .finished, startupCompletion == nil else { return }
        loadViewIfNeeded()
        storageRetryView?.removeFromSuperview()
        storageRetryView = nil
        isWaitingForStorage = false
        hideLoader()
        // Local startup can finish before the view even appears. The flight still runs to the
        // inner gate, and goes through once startup is ready.
        startupCompletion = completion
        finishAnimationIfReady()
    }

    private func finishAnimationIfReady() {
        guard animationPhase == .holding, startupCompletion != nil, !isWaitingForStorage else { return }
        animationPhase = .outro
        if showsMotion, let flight {
            flight.playOutro { [weak self] in
                self?.animationCompleted()
            }
        } else {
            animationCompleted()
        }
    }

    private func animationCompleted() {
        guard animationPhase == .outro else { return }
        animationPhase = .finished
        let completion = startupCompletion
        startupCompletion = nil
        let window = view.window
        completion?()
        handOver(in: window)
    }

    /// The next screen replaces this one at once. What the flight ended on stays over it for a moment and
    /// fades, so a PIN screen's own emblem, standing where the planet landed, simply takes its place.
    private func handOver(in window: UIWindow?) {
        guard let window, window.rootViewController !== self, let landed = flight,
              landed.superview === flightHost else { return }
        landed.removeFromSuperview()
        landed.autoresizingMask = []
        landed.translatesAutoresizingMaskIntoConstraints = true
        landed.frame = window.bounds
        window.addSubview(landed)
        // It fills the window while it fades, also when the window is resized under it.
        landed.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        UIView.animate(withDuration: SacredGeometry.beat(2), delay: 0, options: [.curveEaseOut]) {
            landed.alpha = 0
        } completion: { _ in
            landed.removeFromSuperview()
        }
    }

    func showStorageSpaceRetry(onRetry: @escaping () -> Void) {
        loadViewIfNeeded()
        isWaitingForStorage = true
        startupCompletion = nil
        animationPhase = .holding
        hideLoader()
        flight?.rest()
        storageRetryView?.removeFromSuperview()

        // Safe Mode panel (spec §9.2 U4): calm, theme coloured, one action.
        let title = UILabel()
        WalletSafeMode.title(title, WalletUX.text("Free up some space"))

        let message = UILabel()
        WalletSafeMode.body(message)
        message.text = WalletUX.text("Free up some storage on this iPhone, then check again. Your accounts and keys have not been changed.")

        let retry = WalletSafeMode.button(.safe, title: WalletUX.text("Check again"))
        retry.accessibilityIdentifier = "wallet-upgrade-storage-retry"
        retry.addAction(UIAction { [weak self, weak retry] _ in
            retry?.isEnabled = false
            self?.isWaitingForStorage = false
            self?.showLoader()
            onRetry()
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            WalletSafeMode.centered(WalletSafeMode.shieldEmblem()), title, message, retry
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(24, after: message)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let panel = GlassView()
        panel.fill = .solid
        panel.border = .safe
        panel.shape = .rounded(24)
        panel.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -24),
        ])
        // The panel scrolls (spec §9.4): at large text sizes "Check again"
        // stays reachable instead of being cut off below the screen.
        storageRetryView = WalletSafeMode.installScrollingContent(
            panel, in: view, insets: NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        )
    }
}
