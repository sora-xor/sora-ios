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
import UIKit

final class DetailView: SoramitsuControl {
    public var isShimmerHidden: Bool = true {
        didSet {
            setupShimmer()
        }
    }

    let leftInfoStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .leading
        view.spacing = 4
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let infoButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 14, height: 14))
        view.sora.isHidden = true
        view.sora.tintColor = .fgSecondary
        view.sora.image = R.image.wallet.info()
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    let rightInfoStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.spacing = 8
        return view
    }()
    
    let assetImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.sora.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        view.sora.backgroundColor = .custom(uiColor: .clear)
        return view
    }()
    
    let valueLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        label.heightAnchor.constraint(equalToConstant: 25).isActive = true
        return label
    }()
    
    let fiatValueLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let progressView: ProgressView = {
        let view = ProgressView()
        view.sora.isHidden = true
        view.sora.cornerRadius = .circle
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.heightAnchor.constraint(equalToConstant: 4).isActive = true
        return view
    }()
    
    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        
        addSubviews(leftInfoStackView, rightInfoStackView)
        
        leftInfoStackView.addArrangedSubviews(titleLabel, infoButton)
        rightInfoStackView.addArrangedSubviews(progressView, assetImageView, valueLabel, fiatValueLabel)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            leftInfoStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftInfoStackView.centerYAnchor.constraint(equalTo: rightInfoStackView.centerYAnchor),
            leftInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: rightInfoStackView.leadingAnchor),
            
            rightInfoStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightInfoStackView.topAnchor.constraint(equalTo: topAnchor),
            rightInfoStackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func setupShimmer() {
        if isShimmerHidden { return }
        valueLabel.heightAnchor.constraint(equalToConstant: 25).isActive = true
        valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
    }
}
