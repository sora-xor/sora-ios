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

import SoraUIKit

final class ProgressView: SoramitsuView {
    
    private var widthConstraint: NSLayoutConstraint?

    let progressView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .additionalPolkaswap
        view.sora.cornerRadius = .circle
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
    
    public func set(progressPercentage: Float) {
        widthConstraint?.constant = 64 * CGFloat(progressPercentage / 100)
    }

    private func setup() {
        sora.backgroundColor = .bgSurfaceVariant
        addSubview(progressView)
    }

    private func setupLayout() {
        widthConstraint = progressView.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 64),
            widthConstraint
        ])
    }
}
