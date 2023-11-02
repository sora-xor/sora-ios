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
import Then
import Anchorage
import SoraUI
import SoraUIKit
import SoraFoundation

protocol ReferrerCellDelegate: AnyObject {
    func enterLinkButtonTapped()
}

final class ReferrerCell: SoramitsuTableViewCell {

    private var delegate: ReferrerCellDelegate?
    private let localizationManager = LocalizationManager.shared
    
    // MARK: - Outlets
    private var containerView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.sora.distribution = .fill
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.sora.cornerMask = .all
            $0.spacing = 16
            $0.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            $0.isLayoutMarginsRelativeArrangement = true
        }
    }()

    private lazy var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.text = R.string.localizable.referralYourReferrer(preferredLanguages: .currentLocale)
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.headline2
            $0.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        }
    }()

    private lazy var addressLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.paragraphXS
            $0.sora.lineBreakMode = .byTruncatingMiddle
        }
    }()

    private lazy var enterLinkButton: SoramitsuButton = {
        SoramitsuButton().then {
            let title = SoramitsuTextItem(text: R.string.localizable.referralEnterLinkTitle(preferredLanguages: .currentLocale) ,
                                          fontData: FontType.buttonM ,
                                          textColor: .accentPrimary ,
                                          alignment: .center)
            
            $0.sora.horizontalOffset = 0
            $0.sora.cornerRadius = .circle
            $0.sora.backgroundColor = .accentPrimaryContainer
            $0.sora.attributedText = title
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.enterLinkButtonTapped()
            }
        }
    }()

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    @objc
    func enterLinkButtonTapped() {
        delegate?.enterLinkButtonTapped()
    }
}

extension ReferrerCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? ReferrerViewModel else { return }
        addressLabel.sora.text = viewModel.address
        addressLabel.sora.isHidden = viewModel.address.isEmpty
        enterLinkButton.sora.isHidden = !viewModel.address.isEmpty
        delegate = viewModel.delegate
    }
}

private extension ReferrerCell {

    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addArrangedSubviews([
            titleLabel,
            addressLabel,
            enterLinkButton
        ])
        
        containerView.do {
            $0.topAnchor == contentView.topAnchor + 6
            $0.bottomAnchor == contentView.bottomAnchor - 10
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }
        
        enterLinkButton.do {
            $0.heightAnchor == 56
        }
    }
}
