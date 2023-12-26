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

final class FarmDetailsCell: SoramitsuTableViewCell {
    
    private var farmDetailsItem: FarmDetailsItem?
    
    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()

    private lazy var headerView = PoolDetailsHeaderView()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.spacing = 14
        return view
    }()
    
    public let footerLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.polkaswapFarmingDemeterPower(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        return label
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
        
        containerView.addSubview(headerView)
        containerView.addSubview(stackView)
        containerView.addSubview(footerLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            headerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            headerView.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -24),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -24),
            
            footerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            footerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            footerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
}

extension FarmDetailsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? FarmDetailsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        farmDetailsItem = item

        headerView.titleLabel.sora.text = item.title
        headerView.subtitleLabel.sora.text = item.subtitle

        if let typeImage = item.typeImage.image {
            headerView.typeImageView.sora.picture = .logo(image: typeImage)
        }

        headerView.titleLabel.sora.loadingPlaceholder.type = item.title.isEmpty ? .shimmer : .none
 
        if let image = item.firstAssetImage {
            headerView.firstCurrencyImageView.sora.picture = .logo(image: image)
        }
        headerView.firstCurrencyImageView.sora.loadingPlaceholder.type = item.firstAssetImage == nil ? .shimmer : .none
        
        if let image = item.secondAssetImage {
            headerView.secondCurrencyImageView.sora.picture = .logo(image: image)
        }
        headerView.secondCurrencyImageView.sora.loadingPlaceholder.type = item.firstAssetImage == nil ? .shimmer : .none
        
        if let image = item.rewardAssetImage {
            headerView.rewardImageView.sora.picture = .logo(image: image)
        }
        headerView.rewardImageView.sora.loadingPlaceholder.type = item.rewardAssetImage == nil ? .shimmer : .none

        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let detailsViews = item.detailsViewModel.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.sora.isHidden = detailModel.rewardAssetImage == nil
            
            if let image = item.rewardAssetImage {
                view.assetImageView.sora.picture = .logo(image: image)
            }

            view.titleLabel.sora.text = detailModel.title
            view.titleLabel.sora.loadingPlaceholder.type = detailModel.title.isEmpty ? .shimmer : .none
            
            view.valueLabel.sora.attributedText = detailModel.assetAmountText
            view.valueLabel.sora.loadingPlaceholder.type = detailModel.assetAmountText.text.isEmpty ? .shimmer : .none
            
            view.fiatValueLabel.sora.attributedText = detailModel.fiatAmountText
            view.fiatValueLabel.sora.isHidden = detailModel.fiatAmountText == nil
            
            view.infoButton.sora.isHidden = detailModel.infoHandler == nil

            view.infoButton.sora.addHandler(for: .touchUpInside) { [weak detailModel] in
                detailModel?.infoHandler?()
            }
            
            switch detailModel.type {
            case .casual:
                view.progressView.isHidden = true
            case .progress(let float):
                view.progressView.isHidden = false
                view.progressView.set(progressPercentage: float)
            }
            view.isShimmerHidden = detailModel.infoHandler == nil
            
            return view
        }

        if let detailsView = detailsViews.first {
            stackView.setCustomSpacing(14, after: detailsView)
        }
        
        detailsViews.enumerated().forEach { index, view in
            stackView.addArrangedSubview(view)
            
            if index != detailsViews.count - 1 {
                let separatorView = SoramitsuView()
                separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                separatorView.sora.backgroundColor = .bgPage
                stackView.addArrangedSubview(separatorView)
            }
        }
    }
}

