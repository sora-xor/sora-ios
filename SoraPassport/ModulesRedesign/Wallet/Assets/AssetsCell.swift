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
import SoraFoundation
import Combine

final class AssetsCell: SoramitsuTableViewCell {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var assetsItem: AssetsItem? {
        didSet {
            guard let item = assetsItem else { return }
            item.service?.$moneyText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.moneyLabel.sora.text = value
                    self?.moneyLabel.sora.loadingPlaceholder.type = !value.isEmpty ? .none : .shimmer
                    self?.moneyLabel.sora.cornerRadius = !value.isEmpty ? .zero : .small
                }
                .store(in: &cancellables)
            item.service?.$assetViewModels
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let self = self else { return }
                    self.updateContent(with: value, isNeedRearrange: value.count != self.views.count)
                }
                .store(in: &cancellables)
        }
    }
    
    private var views: [MainScreenAssetView] = []
    private var localizationManager = LocalizationManager.shared
    
    private lazy var arrowButton: WalletHeaderView = {
        let button = WalletHeaderView()
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.assetsItem?.arrowButtonHandler?()
        }
        return button
    }()

    private lazy var moneyLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.cornerRadius = .small
        label.sora.alignment = localizationManager.isRightToLeft ? .left : .right
        return label
    }()

    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()
    
    private let fullStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        return view
    }()

    private let mainInfoView: UIView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
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
            self?.assetsItem?.expandButtonHandler?()
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
        contentView.addSubview(containerView)
        containerView.addSubview(fullStackView)
        
        mainInfoView.addSubviews(arrowButton, moneyLabel)
        fullStackView.addArrangedSubviews(mainInfoView)
        fullStackView.setCustomSpacing(16, after: mainInfoView)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonExpand(preferredLanguages: locale.rLanguages)
        }
        
        localizationManager.addObserver(with: openFullListAssetsButton) { [weak openFullListAssetsButton, weak arrowButton] (_, _) in
            guard let assetsItem = self.assetsItem else { return }
            let currentTitle = localizableTitle.value(for: self.localizationManager.selectedLocale)
            arrowButton?.configure(title: assetsItem.title, isExpand: assetsItem.isExpand)
            openFullListAssetsButton?.sora.attributedText = SoramitsuTextItem(text: currentTitle,
                                                           fontData: FontType.buttonM,
                                                           textColor: .accentPrimary,
                                                                              alignment: .natural)
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            arrowButton.leadingAnchor.constraint(equalTo: mainInfoView.leadingAnchor),
            arrowButton.topAnchor.constraint(equalTo: mainInfoView.topAnchor),
            arrowButton.centerYAnchor.constraint(equalTo: mainInfoView.centerYAnchor),
            arrowButton.trailingAnchor.constraint(equalTo: moneyLabel.leadingAnchor),
            
            moneyLabel.trailingAnchor.constraint(equalTo: mainInfoView.trailingAnchor),
            moneyLabel.centerYAnchor.constraint(equalTo: arrowButton.centerYAnchor),
            moneyLabel.heightAnchor.constraint(equalToConstant: 21),
            moneyLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            fullStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            fullStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
        ])
    }
    
    private func updateContent(with viewModels: [AssetViewModel], isNeedRearrange: Bool = true) {
        if !isNeedRearrange {
            viewModels.enumerated().forEach { (index, assetModel) in
                self.views[index].sora.isHidden = !(assetsItem?.isExpand ?? false)
                
                if let icon = assetModel.icon {
                    self.views[index].assetImageView.sora.picture = .logo(image: icon)
                }
                self.views[index].assetImageView.sora.loadingPlaceholder.type = assetModel.icon == nil ? .shimmer : .none

                if !assetModel.title.isEmpty {
                    self.views[index].titleLabel.sora.text = assetModel.title
                }
                self.views[index].titleLabel.sora.loadingPlaceholder.type = assetModel.title.isEmpty ? .shimmer : .none

                if !assetModel.subtitle.isEmpty {
                    self.views[index].subtitleLabel.sora.text = assetModel.subtitle
                }
                self.views[index].subtitleLabel.sora.loadingPlaceholder.type = assetModel.subtitle.isEmpty ? .shimmer : .none

                if !assetModel.fiatText.isEmpty {
                    self.views[index].amountUpLabel.sora.text = assetModel.fiatText
                }
                self.views[index].amountUpLabel.sora.loadingPlaceholder.type = assetModel.fiatText.isEmpty ? .shimmer : .none

                if let delta = assetModel.deltaPriceText {
                    self.views[index].amountDownLabel.sora.attributedText = delta
                }
                self.views[index].amountDownLabel.sora.loadingPlaceholder.type = assetModel.deltaPriceText == nil ? .shimmer : .none
                self.views[index].sora.addHandler(for: .touchUpInside) { [weak assetsItem] in
                    assetsItem?.assetHandler?(assetModel.identifier)
                }
            }
            return
        }
        fullStackView.arrangedSubviews.filter { $0 is MainScreenAssetView }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        views = viewModels.map { assetModel -> MainScreenAssetView in
            let assetView = MainScreenAssetView()
            assetView.sora.isHidden = !(assetsItem?.isExpand ?? false)
            
            if let icon = assetModel.icon {
                assetView.assetImageView.sora.picture = .logo(image: icon)
            }
            assetView.assetImageView.sora.loadingPlaceholder.type = assetModel.icon == nil ? .shimmer : .none

            if !assetModel.title.isEmpty {
                assetView.titleLabel.sora.text = assetModel.title
            }
            assetView.titleLabel.sora.loadingPlaceholder.type = assetModel.title.isEmpty ? .shimmer : .none

            if !assetModel.subtitle.isEmpty {
                assetView.subtitleLabel.sora.text = assetModel.subtitle
            }
            assetView.subtitleLabel.sora.loadingPlaceholder.type = assetModel.subtitle.isEmpty ? .shimmer : .none

            if !assetModel.fiatText.isEmpty {
                assetView.amountUpLabel.sora.text = assetModel.fiatText
            }
            assetView.amountUpLabel.sora.loadingPlaceholder.type = assetModel.fiatText.isEmpty ? .shimmer : .none

            if let delta = assetModel.deltaPriceText {
                assetView.amountDownLabel.sora.attributedText = delta
            }
            assetView.amountDownLabel.sora.loadingPlaceholder.type = assetModel.deltaPriceText == nil ? .shimmer : .none

            assetView.sora.addHandler(for: .touchUpInside) { [weak assetsItem] in
                assetsItem?.assetHandler?(assetModel.identifier)
            }
            return assetView
        }

        fullStackView.addArrangedSubviews(views)
        
        if let assetView = views.last {
            fullStackView.setCustomSpacing(8, after: assetView)
        }

        fullStackView.addArrangedSubviews(openFullListAssetsButton)
        setNeedsLayout()
    }
}

extension AssetsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AssetsItem else {
            assertionFailure("Incorect type of item")
            return
        }

        if assetsItem == nil {
            assetsItem = item
        }

        arrowButton.configure(title: item.title, isExpand: item.isExpand)

        let viewModels = Array((item.service?.assetViewModels ?? []))
        updateContent(with: viewModels)
        
        openFullListAssetsButton.sora.isHidden = !item.isExpand
        
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        openFullListAssetsButton.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                                          fontData: FontType.buttonM,
                                                                          textColor: .accentPrimary,
                                                                          alignment: alignment)
    }
}

