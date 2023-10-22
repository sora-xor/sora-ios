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
import SoraUIKit

final class SoramitsuLoadingView: SoramitsuView {
    
    let blurredView: UIView = UIView()
    
    let customBlurEffectView: CustomVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .light)
        return CustomVisualEffectView(effect: blurEffect, intensity: 0.5)
    }()
    
    let backgroundView: UIView = {
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.systemGray5
        backgroundView.layer.cornerRadius = 10
        backgroundView.layer.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        return backgroundView
    }()
    
    let activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView()
        activityIndicatorView.style = .large
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicatorView.startAnimating()
        return activityIndicatorView
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .custom(uiColor: .clear)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurredView)
        blurredView.addSubview(customBlurEffectView)
        
        addSubview(backgroundView)
        backgroundView.addSubview(activityIndicatorView)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            blurredView.widthAnchor.constraint(equalTo: widthAnchor),
            blurredView.heightAnchor.constraint(equalTo: heightAnchor),
            
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.widthAnchor.constraint(equalToConstant: 64),
            backgroundView.heightAnchor.constraint(equalToConstant: 64),

            
            activityIndicatorView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        customBlurEffectView.frame = bounds
    }
}
