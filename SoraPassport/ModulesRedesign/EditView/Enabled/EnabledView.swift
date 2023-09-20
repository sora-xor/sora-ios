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
import UIKit
import SoraUIKit
import SnapKit
import SoraFoundation

final class EnabledView: SoramitsuView {
    
    public let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .horizontal
        stackView.spacing = 8
        stackView.sora.isUserInteractionEnabled = false
        return stackView
    }()
    
    public let checkmarkButton: ImageButton = {
        let button = ImageButton(size: CGSize(width: 24, height: 24))
        button.sora.isUserInteractionEnabled = false
        return button
    }()
    
    public lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        label.sora.alignment = (localizationManager.selectedLocalization == "ar") || (localizationManager.selectedLocalization == "he") ? .right : .left
        return label
    }()

    public let tappableArea: SoramitsuControl = {
        let view = SoramitsuControl()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.isHidden = true
        return view
    }()
    
    private let localizationManager = LocalizationManager.shared
    
    init() {
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private extension EnabledView {
    func setup() {
        addSubview(stackView)
        addSubview(tappableArea)
        
        stackView.addArrangedSubviews([
            titleLabel,
            checkmarkButton
        ])
        
        tappableArea.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
            make.height.equalTo(56)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(stackView)
        }
        
        checkmarkButton.snp.makeConstraints { make in
            make.trailing.equalTo(stackView)
        }
    }
}
