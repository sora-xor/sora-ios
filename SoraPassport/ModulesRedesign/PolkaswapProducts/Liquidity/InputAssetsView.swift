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
