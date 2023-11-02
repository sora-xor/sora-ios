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
import SoraFoundation
import SoraUIKit
import SnapKit
import Then

protocol YourReferrerCellDelegate: AnyObject {
    func closeTapped()
}

final class YourReferrerCell: SoramitsuTableViewCell {
    
    private weak var delegate: YourReferrerCellDelegate?
    private let localizationManager = LocalizationManager.shared
    
    private lazy var containerView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.axis = .vertical
            $0.sora.distribution = .fill
            $0.sora.cornerRadius = .max
            $0.spacing = 24
            $0.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            $0.isLayoutMarginsRelativeArrangement = true
        }
    }()
    
    private lazy var descriptionLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.paragraphM
            $0.sora.numberOfLines = 0
            $0.sora.alignment = localizationManager.isRightToLeft ? .right : .left
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()
    
    private lazy var referrersTitleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgSecondary
            $0.sora.font = FontType.textBoldXS
            $0.sora.numberOfLines = 0
            $0.sora.alignment = localizationManager.isRightToLeft ? .right : .left
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()
    
    private lazy var referrersAddressLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.paragraphXS
            $0.sora.numberOfLines = 0
            $0.sora.lineBreakMode = .byTruncatingMiddle
            $0.sora.alignment = localizationManager.isRightToLeft ? .right : .left
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()
    
    private lazy var closeButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.backgroundColor = .accentSecondaryContainer
            $0.sora.cornerRadius = .extraLarge
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.closeButtonTapped()
            }
        }
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupCell() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none
        applyLocalization()
    }
    
    private func setupHierarchy() {
        contentView.addSubview(containerView)
        
        containerView.addArrangedSubviews([
            descriptionLabel,
            referrersTitleLabel,
            referrersAddressLabel,
            closeButton
        ])
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
        
        containerView.setCustomSpacing(8, after: referrersTitleLabel)
        containerView.setCustomSpacing(28, after: referrersAddressLabel)
    }
    
    
    private func closeButtonTapped() {
        guard let delegate = delegate else { return }
        delegate.closeTapped()
    }
}

extension YourReferrerCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? YourReferrerViewModel else { return }
        referrersAddressLabel.sora.text = viewModel.referrer
        self.delegate = viewModel.delegate
    }
}

extension YourReferrerCell: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        descriptionLabel.sora.text = R.string.localizable.referralReferrerDescription(preferredLanguages: languages)
        referrersTitleLabel.sora.text = R.string.localizable.referralReferrerAddress(preferredLanguages: languages)
        
        let title = SoramitsuTextItem(text: R.string.localizable.commonClose(preferredLanguages: languages),
                                      fontData: FontType.buttonM,
                                      textColor: .accentSecondary,
                                      alignment: .center)
        closeButton.sora.attributedText = title
    }
}
