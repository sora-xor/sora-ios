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

final class RecentActivityCell: SoramitsuTableViewCell {
    
    private var heightConstraint: NSLayoutConstraint?
    private var offsetConstraint: NSLayoutConstraint?
    
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var activityItem: RecentActivityItem? {
        didSet {
            cancellables.removeAll()
            guard let item = activityItem else { return }
            item.service?.$historyViewModels
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let self = self else { return }
                    self.updateContent(with: value)
                }
                .store(in: &cancellables)
        }
    }
    private var localizationManager = LocalizationManager.shared

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.assetDetailsRecentActivity(preferredLanguages: .currentLocale)
        return label
    }()

    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
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

    private lazy var openFullActivityButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.showMore(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: .left)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.activityItem?.openFullActivityHandler?()
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
        fullStackView.addArrangedSubviews(titleLabel)
        fullStackView.setCustomSpacing(16, after: titleLabel)
    }

    private func setupConstraints() {
        heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 0)
        offsetConstraint = containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            offsetConstraint,
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            fullStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            fullStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),

            openFullActivityButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func updateSemantics() {
        let semanticContentAttribute: UISemanticContentAttribute = localizationManager.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        
        fullStackView.semanticContentAttribute = semanticContentAttribute
        titleLabel.sora.alignment = alignment
        openFullActivityButton.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.showMore(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: alignment)
    }
    
    private func updateContent(with viewModels: [ActivityContentViewModel]) {
        fullStackView.arrangedSubviews.filter { $0 is ActivityView || $0 is SoramitsuButton }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let activityViews = viewModels.map { model -> ActivityView in
            let view = ActivityView()
            view.isUserInteractionEnabled = true
            
            if let image = model.firstAssetImageViewModel {
                view.firstCurrencyImageView.sora.picture = .logo(image: image)
            }
            view.firstCurrencyImageView.sora.loadingPlaceholder.type = model.firstAssetImageViewModel == nil ? .shimmer : .none
            
            if let image = model.secondAssetImageViewModel {
                view.secondCurrencyImageView.sora.picture = .logo(image: image)
            }
            view.secondCurrencyImageView.sora.loadingPlaceholder.type = model.secondAssetImageViewModel == nil ? .shimmer : .none

            view.titleLabel.sora.text = model.title
            view.titleLabel.sora.loadingPlaceholder.type = model.title.isEmpty ? .shimmer : .none

            view.subtitleLabel.sora.text = model.subtitle
            view.subtitleLabel.sora.loadingPlaceholder.type = model.subtitle.isEmpty ? .shimmer : .none

            if let image = model.typeTransactionImage {
                view.transactionTypeImageView.sora.picture = .logo(image: image)
            }
            view.transactionTypeImageView.sora.loadingPlaceholder.type = model.typeTransactionImage == nil ? .shimmer : .none

            view.amountUpLabel.sora.attributedText = model.firstBalanceText
            view.amountUpLabel.sora.loadingPlaceholder.type = model.firstBalanceText.attributedString.string.isEmpty ? .shimmer : .none
            view.amountView.sora.loadingPlaceholder.type = model.firstBalanceText.attributedString.string.isEmpty ? .shimmer : .none
            
            view.secondCurrencyImageView.isHidden = !model.isNeedTwoImage
            view.oneCurrencyImageView.isHidden = model.isNeedTwoImage
            view.firstCurrencyHeightContstaint?.constant = model.isNeedTwoImage ? 28 : 40

            if let image = model.status.image {
                view.statusImageView.sora.picture = .logo(image: image)
            }
            view.statusImageView.sora.isHidden = model.status.image == nil
            

            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.activityItem?.openActivityDetailsHandler?(model.txHash)
            }
            view.isRightToLeft = localizationManager.isRightToLeft
            return view
        }

        fullStackView.addArrangedSubviews(activityViews)
        if let assetView = activityViews.last {
            fullStackView.setCustomSpacing(8, after: assetView)
        }

        fullStackView.addArrangedSubviews(openFullActivityButton)
        heightConstraint?.isActive = viewModels.isEmpty
        offsetConstraint?.constant = viewModels.isEmpty ? 1 : 16
        setNeedsLayout()
    }
}

extension RecentActivityCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? RecentActivityItem else {
            assertionFailure("Incorect type of item")
            return
        }
        activityItem = item
        
        let viewModels = item.service?.historyViewModels ?? []
        updateContent(with: viewModels)
        updateSemantics()
    }
}

