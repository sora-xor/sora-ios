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

import SoraUIKit
import SnapKit

struct WarningViewModel {
    let title: String
    let descriptionText: String
    var isHidden: Bool
    let containterBackgroundColor: SoramitsuColor
    let contentColor: SoramitsuColor
    
    init(title: String = "",
         descriptionText: String,
         isHidden: Bool,
         containterBackgroundColor: SoramitsuColor,
         contentColor: SoramitsuColor) {
        self.title = title
        self.descriptionText = descriptionText
        self.isHidden = isHidden
        self.containterBackgroundColor = containterBackgroundColor
        self.contentColor = contentColor
    }
}

final class WarningView: SoramitsuView {

    let containterView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.cornerRadius = .max
        return view
    }()
    
    let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .fill
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 8
        return stackView
    }()
    
    let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .statusError
        return label
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }
    
    func setupView(with model: WarningViewModel) {
        descriptionLabel.sora.text = model.descriptionText
        descriptionLabel.sora.textColor = model.contentColor
        
        containterView.sora.borderColor = model.contentColor
        containterView.sora.backgroundColor = model.containterBackgroundColor
        
        sora.isHidden = model.isHidden
    }

    private func setupSubviews() {
        addSubview(containterView)
        containterView.addSubviews(stackView)
        stackView.addArrangedSubviews(descriptionLabel)
    }

    private func setupConstrains() {
        let verticalOffset = 16
        let horizontalOffset = 24
        
        containterView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(containterView).offset(horizontalOffset)
            make.centerX.equalTo(containterView)
            make.top.equalTo(containterView).offset(verticalOffset)
            make.centerY.equalTo(containterView)
        }
    }
}
