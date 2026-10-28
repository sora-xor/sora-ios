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

final class InputAssetsView: SoramitsuView {

    public var firstAsset: InputAssetField = {
        let field = InputAssetField()
        field.sora.assetArrow = R.image.wallet.arrow()
        field.sora.assetImage = R.image.wallet.emptyToken()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        return field
    }()
    
    public let middleButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 24, height: 24))
        view.sora.backgroundColor = .custom(uiColor: Colors.white100)
        view.sora.cornerRadius = .circle
        return view
    }()
    
    public var secondAsset: InputAssetField = {
        let field = InputAssetField()
        field.sora.assetArrow = R.image.wallet.arrow()
        field.sora.assetImage = R.image.wallet.emptyToken()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        return field
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
        translatesAutoresizingMaskIntoConstraints = false
        addSubviews(firstAsset, secondAsset, middleButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            firstAsset.topAnchor.constraint(equalTo: topAnchor),
            firstAsset.leadingAnchor.constraint(equalTo: leadingAnchor),
            firstAsset.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            secondAsset.topAnchor.constraint(equalTo: firstAsset.bottomAnchor, constant: 8),
            secondAsset.leadingAnchor.constraint(equalTo: leadingAnchor),
            secondAsset.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondAsset.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            middleButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            middleButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
