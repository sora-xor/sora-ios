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
import SoraUIKit

final class ActivityIndicatorViewController: SoramitsuViewController {
    /// Theme-aware backdrop (dark in dark mode).
    lazy var blurredView: UIView = {
        let backdrop = NeonScrimView(frame: view.bounds)
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return backdrop
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        
        // A small glass card holding the spinner (spec §7.14).
        let backgroundView = GlassView()
        backgroundView.fill = .strong
        backgroundView.shape = .rounded(16)
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(CGSize(width: 64, height: 64))
        }
        
        let activityIndicatorView = UIActivityIndicatorView()
        activityIndicatorView.style = .large
        activityIndicatorView.color = NeonTokens.current.cyan
        backgroundView.addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        
        activityIndicatorView.startAnimating()
    }
}
