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
import Combine
import SoraFoundation

public final class MainScreenAssetView: SoramitsuControl {
    
    // MARK: - UI
    
    public let assetImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.dynamicTextStyle = .body
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byWordWrapping
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    public let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.dynamicTextStyle = .caption1
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byCharWrapping
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    public let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.dynamicTextStyle = .body
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byCharWrapping
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()

    public let amountDownLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.dynamicTextStyle = .caption1
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byCharWrapping
        label.sora.textColor = .statusSuccess
        label.sora.alignment = .right
        label.sora.text = " "
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    private let columns = UIStackView()
    private let names = UIStackView()
    private let amounts = UIStackView()
    private let localizationManager = LocalizationManager.shared
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setup()
        setupSemantics()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory || bounds.width < 300
        let axis: NSLayoutConstraint.Axis = stacked ? .vertical : .horizontal
        if columns.axis != axis { columns.axis = axis }
        let alignment: UIStackView.Alignment = stacked ? .fill : .top
        if columns.alignment != alignment { columns.alignment = alignment }
        let amountAlignment: NSTextAlignment = stacked
            ? (localizationManager.isRightToLeft ? .right : .left)
            : (localizationManager.isRightToLeft ? .left : .right)
        if amountUpLabel.sora.alignment != amountAlignment { amountUpLabel.sora.alignment = amountAlignment }
        if amountDownLabel.sora.alignment != amountAlignment { amountDownLabel.sora.alignment = amountAlignment }
        accessibilityLabel = [titleLabel.text, subtitleLabel.text, amountUpLabel.text, amountDownLabel.text]
            .compactMap { $0 }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension MainScreenAssetView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        names.axis = .vertical
        names.spacing = 4
        names.addArrangedSubview(titleLabel)
        names.addArrangedSubview(subtitleLabel)
        amounts.axis = .vertical
        amounts.spacing = 4
        amounts.addArrangedSubview(amountUpLabel)
        amounts.addArrangedSubview(amountDownLabel)
        columns.spacing = 12
        columns.alignment = .top
        columns.translatesAutoresizingMaskIntoConstraints = false
        columns.addArrangedSubview(names)
        columns.addArrangedSubview(amounts)
        addSubview(assetImageView)
        addSubview(columns)
        NSLayoutConstraint.activate([
            assetImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            assetImageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            assetImageView.widthAnchor.constraint(equalToConstant: 40),
            assetImageView.heightAnchor.constraint(equalToConstant: 40),
            assetImageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            columns.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 12),
            columns.trailingAnchor.constraint(equalTo: trailingAnchor),
            columns.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            columns.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
    }

    func setupSemantics() {
        let defaultAlignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        let reversedAlignment: NSTextAlignment = localizationManager.isRightToLeft ? .left : .right
        titleLabel.sora.alignment = defaultAlignment
        subtitleLabel.sora.alignment = defaultAlignment
        amountUpLabel.sora.alignment = reversedAlignment
        amountDownLabel.sora.alignment = reversedAlignment
    }
}
