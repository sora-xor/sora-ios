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

final class RecentActivityCell: SoramitsuTableViewCell {
    
    private var heightConstraint: NSLayoutConstraint?
    private var offsetConstraint: NSLayoutConstraint?
    
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var activityItem: RecentActivityItem? {
        didSet {
            guard let item = activityItem else { return }
            item.service.$historyViewModels
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
            model.firstAssetImageViewModel?.loadImage { (icon, _) in
                guard let icon else { return }
                view.firstCurrencyImageView.sora.picture = .logo(image: icon)
            }
            view.firstCurrencyImageView.sora.loadingPlaceholder.type = model.firstAssetImageViewModel == nil ? .shimmer : .none
            
            model.secondAssetImageViewModel?.loadImage { (icon, _) in
                guard let icon else { return }
                view.secondCurrencyImageView.sora.picture = .logo(image: icon)
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
        if activityItem == nil {
            activityItem = item
        }
        
        let viewModels = Array((item.service.historyViewModels))
        updateContent(with: viewModels)
        updateSemantics()
    }
}

