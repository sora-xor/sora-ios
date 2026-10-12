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
import UIKit
import Lottie
import SoraUIKit
import SnapKit

class SplashViewController: UIViewController, SplashViewProtocol {
    
    var presenter: SplashPresenter!
    private var storageRetryView: UIView?
    private var isWaitingForStorage = false
    private enum AnimationPhase { case notStarted, intro, holding, outro, finished }
    private var animationPhase: AnimationPhase = .notStarted
    private var startupCompletion: (() -> Void)?
    
    private lazy var animationView: LottieAnimationView = {
        let animationView = LottieAnimationView(filePath: R.file.soraSplashJson.path()!)
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        Self.applyNeonColors(to: animationView)
        return animationView
    }()

    /// The splash animation was drawn for a light page: its rings are light
    /// grey and the mark is SORA red. Recolour both for the theme in use so
    /// dark mode has no light flash (spec §8.1).
    private static func applyNeonColors(to animationView: LottieAnimationView) {
        let tokens = NeonTokens.current
        func lottie(_ color: UIColor) -> LottieColor {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return LottieColor(r: Double(red), g: Double(green), b: Double(blue), a: Double(alpha))
        }
        let rings: [UIColor] = tokens.isDark
            ? [tokens.canvas, tokens.layer1, tokens.surface]
            : [tokens.canvas, tokens.layer1, tokens.surfaceVariant]
        animationView.setValueProvider(
            GradientValueProvider(rings.map(lottie), locations: [0.75, 0.875, 1]),
            keypath: AnimationKeypath(keypath: "**.Gradient Fill 1.Colors")
        )
        animationView.setValueProvider(
            ColorValueProvider(lottie(tokens.brandRed)),
            keypath: AnimationKeypath(keypath: "**.Fill 1.Color")
        )
    }
    
    private var messageLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.launchScreenLoadingTitle(preferredLanguages: .currentLocale)
        label.sora.font = FontType.textS
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var loaderView: UIActivityIndicatorView = {
        let loaderView = UIActivityIndicatorView(style: .large)
        loaderView.translatesAutoresizingMaskIntoConstraints = false
        loaderView.color = NeonTokens.current.cyan
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
        view.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupHierarchy()
        setupLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard animationPhase == .notStarted, !isWaitingForStorage else { return }
        animationPhase = .intro
        if FxPolicy.reduceEffects || FxPolicy.current.reduceMotion {
            animationView.currentProgress = 0.8
            introCompleted()
        } else {
            animationView.play(fromProgress: 0, toProgress: 0.8, loopMode: .playOnce) { [weak self] _ in
                self?.introCompleted()
            }
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
        view.addSubview(animationView)
        view.addSubview(containerView)
        
        containerView.addSubview(messageLabel)
        containerView.addSubview(loaderView)
    }
    
    private func setupLayout() {
        let containerViewBottomOffset: CGFloat = 76
        let spinnerViewTopOffset: CGFloat = 24
        
        animationView.snp.makeConstraints { make in
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
        // Local startup can finish before the view even appears. Keep the original
        // ring-and-logo introduction, then play its exit once startup is ready.
        startupCompletion = completion
        finishAnimationIfReady()
    }

    private func finishAnimationIfReady() {
        guard animationPhase == .holding, startupCompletion != nil, !isWaitingForStorage else { return }
        animationPhase = .outro
        if FxPolicy.reduceEffects || FxPolicy.current.reduceMotion {
            animationCompleted()
        } else {
            animationView.play(fromProgress: 0.8, toProgress: 1, loopMode: .playOnce) { [weak self] _ in
                self?.animationCompleted()
            }
        }
    }

    private func animationCompleted() {
        guard animationPhase == .outro else { return }
        animationPhase = .finished
        let completion = startupCompletion
        startupCompletion = nil
        completion?()
    }

    func showStorageSpaceRetry(onRetry: @escaping () -> Void) {
        loadViewIfNeeded()
        isWaitingForStorage = true
        startupCompletion = nil
        animationPhase = .holding
        hideLoader()
        animationView.pause()
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
