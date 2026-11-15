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
    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .light)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.5)
        customBlurEffectView.frame = self.view.bounds

        containerView.addSubview(customBlurEffectView)
        return containerView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.systemGray5
        backgroundView.layer.cornerRadius = 10
        backgroundView.layer.masksToBounds = true
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(CGSize(width: 64, height: 64))
        }
        
        // What was sent is in flight: the open circle of heaven turns round the square of earth.
        let seal = SacredSealView()
        seal.workingColor = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        seal.isAccessibilityElement = true
        seal.accessibilityTraits = .updatesFrequently
        seal.accessibilityLabel = R.string.localizable.launchScreenLoadingTitle(preferredLanguages: .currentLocale)
        backgroundView.addSubview(seal)
        seal.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(CGSize(width: 38, height: 38))
        }
    }
}
