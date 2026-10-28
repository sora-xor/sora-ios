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

import SoraUIKit
import SnapKit
import SoraFoundation

final class FriendsCell: SoramitsuTableViewCell {
    
    private var friendsItem: FriendsItem?
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
        label.sora.text = R.string.localizable.settingsInviteTitle(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.headline2
        label.sora.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()
    
    private lazy var descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.referralTitle(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.paragraphXS
        label.sora.numberOfLines = 0
        return label
    }()
    
    private lazy var pictureView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.archerGirl()
        imageView.sora.contentMode = .scaleAspectFill
        imageView.setContentHuggingPriority(.required, for: .vertical)
        return imageView
    }()
    
    private lazy var startInvitingButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.referralStartInviting(preferredLanguages: .currentLocale) ,
                                      fontData: FontType.textBoldS ,
                                      textColor: .custom(uiColor: Colors.white100),
                                      alignment: .center)

        let button = SoramitsuButton()
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.attributedText = title
        button.sora.isUserInteractionEnabled = false
        button.sora.horizontalOffset = 8
        return button
    }()
    
    private lazy var closeButton: ImageButton = {
        let button = ImageButton(size: CGSize(width: 32, height: 32))
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .bgSurface
        button.sora.image = R.image.close()
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.friendsItem?.onClose?()
        }
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
        contentView.addSubview(closeButton)

        containerView.addSubviews([titleLabel, descriptionLabel, startInvitingButton, pictureView])
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
            make.trailing.equalTo(pictureView.snp.leading).offset(-17)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalTo(containerView).offset(24)
            make.trailing.equalTo(pictureView.snp.leading).offset(-17)
        }
        
        startInvitingButton.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
            make.leading.equalTo(containerView).offset(24)
            make.height.equalTo(32)
            make.bottom.equalTo(containerView).offset(-16)
        }
        
        pictureView.snp.makeConstraints { make in
            make.trailing.bottom.centerY.equalTo(containerView)
            make.width.equalTo(136)
            make.height.equalTo(164)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(24)
            make.trailing.equalTo(contentView).offset(-32)
        }
    }
    
    func setupSemantics() {
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        titleLabel.sora.alignment = alignment
        descriptionLabel.sora.alignment = alignment
    }
}

extension FriendsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? FriendsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        friendsItem = item
        
        setupSemantics()
    }
}
