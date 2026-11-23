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
        field.sora.assetImage = PortfolioGlyphs.emptyTokenImage()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        return field
    }()
    
    /// A raised white pad between the two cards; 44 points so a thumb finds it.
    public let middleButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 44, height: 44))
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.cornerRadius = .circle
        return view
    }()

    private let middlePad: LitPlateLayer = {
        let pad = LitPlateLayer()
        pad.cornerRadiusValue = 22
        pad.elevation = 8
        return pad
    }()
    
    public var secondAsset: InputAssetField = {
        let field = InputAssetField()
        field.sora.assetArrow = R.image.wallet.arrow()
        field.sora.assetImage = PortfolioGlyphs.emptyTokenImage()
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
        // The cards reach the edges of this view; clipping would cut their
        // focus glow.
        sora.clipsToBounds = false
        translatesAutoresizingMaskIntoConstraints = false
        addSubviews(firstAsset, secondAsset, middleButton)
        middleButton.layer.insertSublayer(middlePad, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        middlePad.frame = middleButton.bounds
        CATransaction.commit()
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
