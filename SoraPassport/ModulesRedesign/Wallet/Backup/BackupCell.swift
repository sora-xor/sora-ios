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
import SoraFoundation

final class BackupCell: SoramitsuTableViewCell {

    private var backupItem: BackupItem?
    private let localizationManager = LocalizationManager.shared

    private lazy var containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = false
        return view
    }()

    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.walletBackup(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.headline2
        label.numberOfLines = 0
        return label
    }()

    private lazy var descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.protectLossAccessFunds(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.paragraphXS
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var pictureView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.katanaGirl()
        imageView.sora.contentMode = .scaleAspectFill
        imageView.setContentHuggingPriority(.required, for: .vertical)
        return imageView
    }()
    
    private lazy var backupButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.backupNow(preferredLanguages: .currentLocale),
                                      fontData: FontType.textBoldS ,
                                      textColor: .custom(uiColor: Colors.white100),
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 8
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.attributedText = title
        button.sora.isUserInteractionEnabled = false
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    
    private func setupHierarchy() {
        contentView.addSubview(containerView)

        containerView.addSubviews([titleLabel, descriptionLabel, backupButton, pictureView])
    }
    
    private func setupLayout() {
        
        containerView.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(8)
            make.leading.equalTo(contentView).offset(16)
            make.center.equalTo(contentView)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(containerView).offset(16)
            make.leading.equalTo(containerView).offset(24)
            make.trailing.equalTo(pictureView.snp.leading).offset(-8)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalTo(containerView).offset(24)
            make.trailing.equalTo(pictureView.snp.leading).offset(-8)
        }
        
        backupButton.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
            make.leading.equalTo(containerView).offset(24)
            make.bottom.equalTo(containerView).offset(-24)
            make.height.equalTo(32)
        }
        
        pictureView.snp.makeConstraints { make in
            make.centerY.trailing.equalTo(containerView)
            make.width.equalTo(164)
            make.height.equalTo(148)
        }
    }
    
    func setupSemantics() {
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        titleLabel.sora.alignment = alignment
        descriptionLabel.sora.alignment = alignment
    }
}

extension BackupCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? BackupItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        backupItem = item
        
        setupSemantics()
    }
}
