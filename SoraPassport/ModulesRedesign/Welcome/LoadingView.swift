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
    
    /// Theme-aware backdrop (dark in dark mode).
    let blurredView: UIView = {
        let view = NeonScrimView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// A small glass card holding the spinner (spec §7.14).
    let backgroundView: UIView = {
        let backgroundView = GlassView()
        backgroundView.fill = .strong
        backgroundView.shape = .rounded(16)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        return backgroundView
    }()
    
    let activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView()
        activityIndicatorView.style = .large
        activityIndicatorView.color = NeonTokens.current.cyan
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
        
        addSubview(backgroundView)
        backgroundView.addSubview(activityIndicatorView)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            blurredView.widthAnchor.constraint(equalTo: widthAnchor),
            blurredView.heightAnchor.constraint(equalTo: heightAnchor),
            blurredView.centerXAnchor.constraint(equalTo: centerXAnchor),
            blurredView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.widthAnchor.constraint(equalToConstant: 64),
            backgroundView.heightAnchor.constraint(equalToConstant: 64),

            
            activityIndicatorView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
        ])
    }
}
