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
