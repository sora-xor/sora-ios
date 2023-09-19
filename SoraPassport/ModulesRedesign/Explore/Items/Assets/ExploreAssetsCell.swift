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
import SoraFoundation
import Combine

final class ExploreAssetsCell: SoramitsuTableViewCell {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var assetsItem: ExploreAssetsItem? {
        didSet {
            guard let item = assetsItem else { return }
            item.viewModelService?.$viewModels
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.updateContent(with: Array(value.prefix(5)))
                }
                .store(in: &cancellables)
        }
    }
    
    private var localizationManager = LocalizationManager.shared
    
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        return label
    }()
    
    private let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        return label
    }()

    private let fullStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let mainInfoView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        return view
    }()

    private lazy var openFullListAssetsButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: .natural)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.assetsItem?.expandHandler?()
        }
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(fullStackView)
        
        mainInfoView.addArrangedSubviews(titleLabel, subtitleLabel)
        fullStackView.addArrangedSubviews(mainInfoView)
        fullStackView.setCustomSpacing(16, after: mainInfoView)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonExpand(preferredLanguages: locale.rLanguages)
        }
        
        localizationManager.addObserver(with: openFullListAssetsButton) { [weak openFullListAssetsButton] (_, _) in
            let currentTitle = localizableTitle.value(for: self.localizationManager.selectedLocale)
            openFullListAssetsButton?.sora.attributedText = SoramitsuTextItem(text: currentTitle,
                                                           fontData: FontType.buttonM,
                                                           textColor: .accentPrimary,
                                                           alignment: .natural)
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            fullStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fullStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
        ])
    }
    
    private func updateContent(with viewModels: [ExploreAssetViewModel]) {
        fullStackView.arrangedSubviews.filter { $0 is ExploreAssetView || $0 is SoramitsuButton }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let assetViews = viewModels.compactMap { assetModel -> ExploreAssetView in
            let assetView = ExploreAssetView()
            assetView.serialNumber.sora.text = assetModel.serialNumber
            if let icon = assetModel.icon {
                assetView.assetImageView.sora.picture = .logo(image: icon)
                assetView.assetImageView.sora.loadingPlaceholder.type = .none
            }

            if let title = assetModel.title {
                assetView.titleLabel.sora.text = title
                assetView.titleLabel.sora.loadingPlaceholder.type = .none
            }

            if let subtitle = assetModel.marketCap {
                assetView.subtitleLabel.sora.text = subtitle
                assetView.subtitleLabel.sora.loadingPlaceholder.type = .none
            }

            if let price = assetModel.price {
                assetView.amountUpLabel.sora.text = price
                assetView.amountUpLabel.sora.loadingPlaceholder.type = .none
            }

            assetView.tappableArea.sora.isHidden = false
            assetView.tappableArea.sora.addHandler(for: .touchUpInside) { [weak assetsItem] in
                guard let assetId = assetModel.assetId else { return }
                assetsItem?.assetHandler?(assetId)
            }

            return assetView
        }

        fullStackView.addArrangedSubviews(assetViews)
        
        if let assetView = assetViews.last {
            fullStackView.setCustomSpacing(8, after: assetView)
        }

        fullStackView.addArrangedSubviews(openFullListAssetsButton)
    }
    
    private func updateLayout() {
        let alignment: NSTextAlignment = (localizationManager.selectedLocalization == "ar") || (localizationManager.selectedLocalization == "he") ? .right : .left
        titleLabel.sora.alignment = alignment
        subtitleLabel.sora.alignment = alignment
        openFullListAssetsButton.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: alignment)
    }
}

extension ExploreAssetsCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? ExploreAssetsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        assetsItem = item
        titleLabel.sora.text = item.title
        subtitleLabel.sora.text = item.subTitle
        
        let viewModels = Array((item.viewModelService?.viewModels ?? []).prefix(5))
        updateContent(with: viewModels)
        updateLayout()
    }
}
