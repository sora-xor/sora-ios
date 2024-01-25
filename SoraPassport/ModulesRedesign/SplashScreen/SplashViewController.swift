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
    
    private lazy var animationView: LottieAnimationView = {
        let animationView = LottieAnimationView(filePath: R.file.soraSplashJson.path()!)
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        return animationView
    }()
    
    private var messageLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.launchScreenLoadingTitle(preferredLanguages: .currentLocale)
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgPrimary
        label.sora.supportsPaletteMode = false
        label.sora.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var loaderView: UIActivityIndicatorView = {
        let loaderView = UIActivityIndicatorView(style: .large)
        loaderView.translatesAutoresizingMaskIntoConstraints = false
        loaderView.color = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        return loaderView
    }()
    
    private var containerView: SoramitsuView = {
        let containerView = SoramitsuView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.sora.isHidden = true
        return containerView
    }()
    
    override func viewDidLoad() {
        view.backgroundColor = R.color.baseBackground()
        setupHierarchy()
        setupLayout()
        animationView.play(fromProgress: 0, toProgress: 0.8, loopMode: .playOnce) { [weak self] _ in
            self?.presenter.showIsLoading(after: 5.0) { [weak self] in
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
        containerView.sora.isHidden = false
        loaderView.startAnimating()
    }
    
    private func hideLoader() {
        containerView.sora.isHidden = true
        loaderView.stopAnimating()
    }
    
    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        hideLoader()
        animationView.play(fromProgress: 0.8, toProgress: 1, loopMode: .playOnce) { (_) in
            completion()
        }
    }
}
