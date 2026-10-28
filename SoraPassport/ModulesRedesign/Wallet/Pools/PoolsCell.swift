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

final class PoolsCell: SoramitsuTableViewCell {
    
    private var heightConstraint: NSLayoutConstraint?
    private var cancellables: Set<AnyCancellable> = []
    
    private var poolsItem: PoolsItem? {
        didSet {
            cancellables.removeAll()
            guard let item = poolsItem else { return }
            item.service?.$moneyText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.moneyLabel.sora.loadingPlaceholder.type = !value.isEmpty ? .none : .shimmer
                    self?.moneyLabel.sora.text = value
                    self?.applyTotalStyle()
                }
                .store(in: &cancellables)
            item.service?.$poolViewModels
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let self = self else { return }
                    self.updateContent(with: value)
                }
                .store(in: &cancellables)
        }
    }
    private var views: [MainScreenPoolView]?
    private var localizationManager = LocalizationManager.shared
    
    private lazy var arrowButton: WalletHeaderView = {
        let button = WalletHeaderView()
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolsItem?.arrowButtonHandler?()
        }
        return button
    }()

    private let moneyLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.cornerRadius = .small
        label.sora.alignment = .right
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

    private lazy var openFullListPoolsButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: .left)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolsItem?.expandButtonHandler?()
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
        
        LocalizationManager.shared.addObserver(with: openFullListPoolsButton) { [weak openFullListPoolsButton, weak arrowButton] (_, _) in
            guard let poolsItem = self.poolsItem else { return }
            let currentTitle = localizableTitle.value(for: LocalizationManager.shared.selectedLocale)
            arrowButton?.configure(title: poolsItem.title, isExpand: poolsItem.isExpand)
            openFullListPoolsButton?.sora.attributedText = SoramitsuTextItem(text: currentTitle,
                                                           fontData: FontType.buttonM,
                                                           textColor: .accentPrimary,
                                                           alignment: .left)
        }
    }

    private func setupConstraints() {
        heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 0)
        
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
    
    private func updateContent(with viewModels: [PoolViewModel]) {
        heightConstraint?.isActive = viewModels.isEmpty || poolsItem?.isHidden == true
        if views == nil {
            rearange(with: viewModels)
            return
        }

        if viewModels.count == views?.count {
            viewModels.enumerated().forEach { (index, poolModel) in
                self.update(poolView: self.views?[index], poolModel: poolModel)
            }
            return
        }
        
        rearange(with: viewModels)
    }
    
    func rearange(with viewModels: [PoolViewModel]) {
        fullStackView.arrangedSubviews.filter { $0 is MainScreenPoolView }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        views = viewModels.map { poolModel -> MainScreenPoolView in
            let poolView = MainScreenPoolView()
            update(poolView: poolView, poolModel: poolModel)
            return poolView
        }

        fullStackView.addArrangedSubviews(views ?? [])
        
        if let poolView = views?.last {
            fullStackView.setCustomSpacing(8, after: poolView)
        }

        fullStackView.addArrangedSubviews(openFullListPoolsButton)
        layoutIfNeeded()
        setNeedsLayout()
    }
    
    func update(poolView: MainScreenPoolView?, poolModel: PoolViewModel) {
        poolView?.sora.isHidden = !(self.poolsItem?.isExpand ?? false)
        if let icon = poolModel.baseAssetImage {
            poolView?.firstCurrencyImageView.sora.picture = .logo(image: icon)
        }
        poolView?.firstCurrencyImageView.sora.loadingPlaceholder.type = poolModel.baseAssetImage != nil ? .none : .shimmer

        if let icon = poolModel.targetAssetImage {
            poolView?.secondCurrencyImageView.sora.picture = .logo(image: icon)
        }
        poolView?.secondCurrencyImageView.sora.loadingPlaceholder.type = poolModel.targetAssetImage != nil ? .none : .shimmer

        if let icon = poolModel.rewardAssetImage {
            poolView?.rewardImageView.sora.picture = .logo(image: icon)
        }
        poolView?.rewardImageView.sora.loadingPlaceholder.type = poolModel.rewardAssetImage != nil ? .none : .shimmer
        
        if !poolModel.title.isEmpty {
            poolView?.titleLabel.sora.text = poolModel.title
        }
        poolView?.titleLabel.sora.loadingPlaceholder.type = !poolModel.title.isEmpty ? .none : .shimmer

        if !poolModel.subtitle.isEmpty {
            poolView?.subtitleLabel.sora.text = poolModel.subtitle
        }
        poolView?.subtitleLabel.sora.loadingPlaceholder.type = !poolModel.subtitle.isEmpty ? .none : .shimmer

        // Once the price read has finished, a pool without a price shows
        // no value instead of a loading placeholder that never ends.
        let waiting = !poolModel.priceLoadFinished
        if !poolModel.fiatText.isEmpty || !waiting {
            poolView?.amountUpLabel.sora.text = poolModel.fiatText
        }
        poolView?.amountUpLabel.sora.loadingPlaceholder.type = poolModel.fiatText.isEmpty && waiting ? .shimmer : .none
        
        let rewardPictures: [Picture] = poolModel.farmedRewardAssetsImages.map { .logo(image: $0) }
        poolView?.setupFarmedAssetImages(pictures: rewardPictures)
        poolView?.farmedRewardAssetStackView.sora.loadingPlaceholder.type = poolModel.targetAssetImage != nil ? .none : .shimmer

        poolView?.isUserInteractionEnabled = !poolModel.title.isEmpty
        
        poolView?.sora.removeAllHandlers(for: .touchUpInside)
        poolView?.sora.addHandler(for: .touchUpInside) { [weak poolsItem] in
            poolsItem?.poolHandler?(poolModel.identifier)
        }
    }
    
}

private extension PoolsCell {
    /// "Price unavailable" is a quiet notice, not an amount.
    func applyTotalStyle() {
        let unavailable = poolsItem?.service?.priceIsUnavailable ?? false
        moneyLabel.sora.font = unavailable ? FontType.textS : FontType.headline2
        moneyLabel.sora.textColor = unavailable ? .fgSecondary : .fgPrimary
    }
}

extension PoolsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PoolsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        poolsItem = item
       
        moneyLabel.sora.text = item.service?.moneyText
        applyTotalStyle()
        moneyLabel.sora.alignment = localizationManager.isRightToLeft ? .left : .right

        arrowButton.configure(title: item.title, isExpand: item.isExpand)

        let viewModels = Array(item.service?.poolViewModels ?? [])
        updateContent(with: viewModels)

        openFullListPoolsButton.sora.isHidden = !item.isExpand
        openFullListPoolsButton.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                                          fontData: FontType.buttonM,
                                                                          textColor: .accentPrimary,
                                                                          alignment: localizationManager.isRightToLeft ? .right : .left)
        heightConstraint?.isActive = item.service?.poolViewModels.isEmpty ?? true || item.isHidden
    }
}

