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
        label.sora.text = " "
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
        label.sora.text = " "
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
        label.sora.font = FontType.amountM
        label.sora.dynamicTextStyle = .body
        label.sora.text = " "
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byCharWrapping
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()

    public let amountDownLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.amountS
        label.sora.dynamicTextStyle = .caption1
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byCharWrapping
        label.sora.textColor = .statusSuccess
        label.sora.alignment = .right
        label.sora.text = " "
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    private let columns = UIStackView()
    private let names = UIStackView()
    private let amounts = UIStackView()
    private var amountWidth: NSLayoutConstraint!
    private let localizationManager = LocalizationManager.shared
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setup()
        setupSemantics()
    }
    
    public override func layoutSubviews() {
        updateColumns(for: bounds.width)
        super.layoutSubviews()
    }

    /// Read from the labels whenever VoiceOver asks. Set during layout, it kept the old amount when a new one moved nothing.
    public override var accessibilityLabel: String? {
        get {
            super.accessibilityLabel ?? [titleLabel.text, subtitleLabel.text, amountUpLabel.text, amountDownLabel.text]
                .compactMap { $0 }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ")
        }
        set { super.accessibilityLabel = newValue }
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                                withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                                verticalFittingPriority: UILayoutPriority) -> CGSize {
        updateColumns(for: targetSize.width)
        return super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority,
                                            verticalFittingPriority: verticalFittingPriority)
    }

    /// Sets the row out for `width`: names and amounts side by side, or the amounts under the names when
    /// there is no room for both. A row laid out this way after its card was measured the other way has
    /// the wrong height, so whoever measures a card of rows calls this first with the rows' width.
    func updateColumns(for width: CGFloat) {
        guard width > 52 else { return }
        let available = width - 52
        let loadingAmount = amountUpLabel.sora.loadingPlaceholder.type == .shimmer
            || amountDownLabel.sora.loadingPlaceholder.type == .shimmer
        let naturalAmountWidth = ceil(max(loadingAmount ? 64 : 0,
                                          max(amountUpLabel.attributedText?.size().width ?? 0,
                                              amountDownLabel.attributedText?.size().width ?? 0)))
        // Under 280 points, not 300: a row of the network picker is 295 wide on a 375-point phone (iPhone SE,
        // 13 mini), where a short tag fits beside the name as it does on every wider phone.
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || width < 280 || naturalAmountWidth > available * 0.45
        let axis: NSLayoutConstraint.Axis = stacked ? .vertical : .horizontal
        if stacked { amountWidth.isActive = false }
        if columns.axis != axis { columns.axis = axis }
        if !stacked {
            amountWidth.constant = naturalAmountWidth
            amountWidth.isActive = true
        }
        let alignment: UIStackView.Alignment = stacked ? .fill : .top
        if columns.alignment != alignment { columns.alignment = alignment }
        let amountAlignment: NSTextAlignment = stacked
            ? (localizationManager.isRightToLeft ? .right : .left)
            : (localizationManager.isRightToLeft ? .left : .right)
        if amountUpLabel.sora.alignment != amountAlignment { amountUpLabel.sora.alignment = amountAlignment }
        if amountDownLabel.sora.alignment != amountAlignment { amountDownLabel.sora.alignment = amountAlignment }
        let nameWidth = stacked ? available : max(1, available - naturalAmountWidth - columns.spacing)
        for label in [titleLabel, subtitleLabel] where label.preferredMaxLayoutWidth != nameWidth {
            label.preferredMaxLayoutWidth = nameWidth
        }
        let valueWidth = stacked ? available : max(1, naturalAmountWidth)
        for label in [amountUpLabel, amountDownLabel] where label.preferredMaxLayoutWidth != valueWidth {
            label.preferredMaxLayoutWidth = valueWidth
        }
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
        // This is one control: stacks must not consume touches on its text.
        columns.isUserInteractionEnabled = false
        columns.alignment = .top
        columns.translatesAutoresizingMaskIntoConstraints = false
        columns.addArrangedSubview(names)
        columns.addArrangedSubview(amounts)
        amountWidth = amounts.widthAnchor.constraint(equalToConstant: 0)
        for label in [titleLabel, subtitleLabel, amountUpLabel, amountDownLabel] {
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
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
