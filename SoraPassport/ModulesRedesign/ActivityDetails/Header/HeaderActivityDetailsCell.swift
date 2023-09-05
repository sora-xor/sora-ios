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

final class HeaderActivityDetailsCell: SoramitsuTableViewCell {
    
    private var poolDetailsItem: HeaderActivityDetailsItem?
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        return view
    }()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.alignment = .center
        view.spacing = 14
        view.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.heightAnchor.constraint(equalToConstant: 72).isActive = true
        view.widthAnchor.constraint(equalToConstant: 72).isActive = true
        return view
    }()

    let firstCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        view.widthAnchor.constraint(equalToConstant: 48).isActive = true
        return view
    }()

    let secondCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        view.widthAnchor.constraint(equalToConstant: 48).isActive = true
        view.isHidden = true
        return view
    }()
    
    let oneCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 72).isActive = true
        view.widthAnchor.constraint(equalToConstant: 72).isActive = true
        return view
    }()
    
    private let transactionTypeView: SoramitsuView = {
        var view = SoramitsuView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        return view
    }()
    
    let transactionTypeImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.tintColor = .fgSecondary
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return view
    }()
    
    let transactionTypeLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let firstAmoutLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        return label
    }()
    
    let transactionActionImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.tintColor = .fgSecondary
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return view
    }()
    
    let secondAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        return label
    }()
    
    private let detailsStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.spacing = 8
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        currenciesView.addSubview(firstCurrencyImageView)
        currenciesView.addSubview(secondCurrencyImageView)
        currenciesView.addSubview(oneCurrencyImageView)
        
        transactionTypeView.addSubviews(transactionTypeImageView, transactionTypeLabel)
        
        stackView.addArrangedSubviews(currenciesView,
                                      transactionTypeView,
                                      firstAmoutLabel,
                                      transactionActionImageView,
                                      secondAmountLabel,
                                      detailsStackView)
        stackView.setCustomSpacing(8, after: currenciesView)
        stackView.setCustomSpacing(8, after: transactionTypeView)
        stackView.setCustomSpacing(2, after: firstAmoutLabel)
        stackView.setCustomSpacing(2, after: transactionActionImageView)
        stackView.setCustomSpacing(24, after: secondAmountLabel)
        
        contentView.addSubviews(containerView, stackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),

            secondCurrencyImageView.trailingAnchor.constraint(equalTo: currenciesView.trailingAnchor),
            secondCurrencyImageView.bottomAnchor.constraint(equalTo: currenciesView.bottomAnchor),
            
            oneCurrencyImageView.centerXAnchor.constraint(equalTo: currenciesView.centerXAnchor),
            oneCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            
            transactionTypeImageView.leadingAnchor.constraint(equalTo: transactionTypeView.leadingAnchor),
            transactionTypeImageView.topAnchor.constraint(equalTo: transactionTypeView.topAnchor),
            transactionTypeImageView.centerYAnchor.constraint(equalTo: transactionTypeView.centerYAnchor),
            
            transactionTypeLabel.trailingAnchor.constraint(equalTo: transactionTypeView.trailingAnchor),
            transactionTypeLabel.centerYAnchor.constraint(equalTo: transactionTypeImageView.centerYAnchor),
            transactionTypeLabel.leadingAnchor.constraint(equalTo: transactionTypeImageView.trailingAnchor, constant: 4),
            
            containerView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: stackView.topAnchor, constant: 36),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            detailsStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 24),
            detailsStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -24),
        ])
    }
}

extension HeaderActivityDetailsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? HeaderActivityDetailsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        firstCurrencyImageView.isHidden = item.secondAssetImageViewModel == nil
        secondCurrencyImageView.isHidden = item.secondAssetImageViewModel == nil
        oneCurrencyImageView.isHidden = item.secondAssetImageViewModel != nil
        
        item.firstAssetImageViewModel?.loadImage { [weak self] (icon, _) in
            self?.firstCurrencyImageView.image = icon
        }
        
        item.secondAssetImageViewModel?.loadImage { [weak self] (icon, _) in
            self?.secondCurrencyImageView.image = icon
        }
        
        item.firstAssetImageViewModel?.loadImage { [weak self] (icon, _) in
            self?.oneCurrencyImageView.image = icon
        }
        
        transactionTypeImageView.image = item.typeTransactionImage
        transactionTypeLabel.sora.text = item.typeText
        
        firstAmoutLabel.sora.attributedText = item.firstBalanceText
        stackView.setCustomSpacing(item.secondBalanceText != nil ? 2 : 24, after: firstAmoutLabel)
        
        transactionActionImageView.isHidden = item.actionTransactionImage == nil
        transactionActionImageView.image = item.actionTransactionImage
        
        secondAmountLabel.sora.isHidden = item.secondBalanceText == nil
        secondAmountLabel.sora.attributedText = item.secondBalanceText

        stackView.arrangedSubviews.filter { $0 is ActivityDetailView }.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let detailsViews = item.details.map { detailModel -> DetailView in
            let view = DetailView()
            view.titleLabel.sora.text = detailModel.title
            view.valueLabel.sora.attributedText = detailModel.assetAmountText
            view.infoButton.sora.isHidden = detailModel.infoHandler == nil
            view.assetImageView.isHidden = detailModel.statusAssetImage == nil
            view.assetImageView.image = detailModel.statusAssetImage
            view.infoButton.sora.addHandler(for: .touchUpInside) { [weak detailModel] in
                detailModel?.infoHandler?()
            }
            return view
        }
        
        detailsViews.enumerated().forEach { index, view in
            detailsStackView.addArrangedSubview(view)
            
            if index != detailsViews.count - 1 {
                let separatorView = SoramitsuView()
                separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                separatorView.sora.backgroundColor = .bgPage
                detailsStackView.addArrangedSubview(separatorView)
            }
        }
    }
}

