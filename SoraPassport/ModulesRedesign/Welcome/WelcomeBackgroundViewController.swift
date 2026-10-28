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
import SSFCloudStorage
import SoraUIKit

final class WelcomeBackgroundViewController: UIViewController {
    lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.wallet.welcomeBackgound()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Dims the artwork in dark mode so light bar titles and buttons on it
    /// stay readable.
    private let scrim: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupView()
        setupConstraints()
        applyTheme()
        SoramitsuUI.updates.addObserver(self)
    }

    private func applyTheme() {
        scrim.backgroundColor = NeonTokens.current.isDark ? NeonTokens.current.scrim : .clear
    }
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        view.addSubview(imageView)
        view.addSubview(scrim)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension WelcomeBackgroundViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { applyTheme() }
    }
}
