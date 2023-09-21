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

import UIKit
import SoraUIKit
import SnapKit
import SoraFoundation

final class EnabledCell: SoramitsuTableViewCell {
    
    private var enabledItem: EnabledItem?
    
    private lazy var mainStackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.backgroundColor = .custom(uiColor: .clear)
        stackView.spacing = 24
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private lazy var enabledStackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.cornerRadius = .max
        stackView.sora.backgroundColor = .bgSurface
        stackView.sora.isHidden = true
        stackView.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private lazy var enabledLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.commonEnabled(preferredLanguages: .currentLocale).uppercased()
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        label.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        return label
    }()
    
    private lazy var disabledStackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.cornerRadius = .max
        stackView.sora.backgroundColor = .bgSurface
        stackView.sora.isHidden = true
        stackView.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private lazy var disabledLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.commonDisabled(preferredLanguages: .currentLocale).uppercased()
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        label.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        return label
    }()
    
    private let localizationManager = LocalizationManager.shared
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupHierarchy() {
        contentView.addSubview(mainStackView)
        
        mainStackView.addArrangedSubviews([
            enabledStackView,
            disabledStackView
        ])
        
        enabledStackView.addArrangedSubview(enabledLabel)
        disabledStackView.addArrangedSubview(disabledLabel)
    }
    
    private func setupLayout() {
        mainStackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
    }
    
    private func removeSubviews() {
        enabledStackView.arrangedSubviews.filter { $0 is EnabledView }.forEach { subview in
            enabledStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        disabledStackView.arrangedSubviews.filter { $0 is EnabledView }.forEach { subview in
            disabledStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
}

extension EnabledCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? EnabledItem else {
            assertionFailure("Incorect type of item")
            return
        }
        let enabledIds = ApplicationConfig.shared.enabledCardIdentifiers
        
        enabledItem = item
        
        removeSubviews()
        
        let enabledViews = item.enabledViewModels.filter { enabledIds.contains($0.id) }.map { enabledModel -> EnabledView in
            let view = EnabledView()
            view.titleLabel.sora.text = enabledModel.title
            view.checkmarkButton.sora.image = R.image.checkboxSelected()
            view.checkmarkButton.sora.isEnabled = enabledModel.state == .selected
            view.tappableArea.sora.isHidden = false
            view.tappableArea.sora.addHandler(for: .touchUpInside) { [weak enabledItem] in
                enabledItem?.onTap?(enabledModel.id)
            }
            return view
        }

        let disabledViews = item.enabledViewModels.filter { !enabledIds.contains($0.id) }.map { enabledModel -> EnabledView in
            let view = EnabledView()
            view.titleLabel.sora.text = enabledModel.title
            view.checkmarkButton.sora.image = R.image.checkboxDefault()?.tinted(with: SoramitsuUI.shared.theme.palette.color(.accentPrimary))
            view.tappableArea.sora.isHidden = false
            view.tappableArea.sora.addHandler(for: .touchUpInside) { [weak enabledItem] in
                enabledItem?.onTap?(enabledModel.id)
            }
            enabledModel.state = .disabled
            return view
        }

        enabledStackView.addArrangedSubviews(enabledViews)
        enabledStackView.sora.isHidden = enabledViews.isEmpty

        disabledStackView.addArrangedSubviews(disabledViews)
        disabledStackView.sora.isHidden = disabledViews.isEmpty
    }
}

