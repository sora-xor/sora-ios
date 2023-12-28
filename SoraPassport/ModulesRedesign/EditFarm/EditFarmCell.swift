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

final class EditFarmCell: SoramitsuTableViewCell {
    
    private var item: EditFarmItem?
    private let localizationManager = LocalizationManager.shared
    
    private var viewModel: EditFarmViewModelProtocol?
    
    let containerView: SoramitsuStackView = {
        let view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.spacing = 24
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    private let headerLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.selectPoolShare(preferredLanguages: .currentLocale)
        return label
    }()
    
    private let sliderView: FarmSliderView = {
        let view = FarmSliderView()
        return view
    }()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.spacing = 14
        return view
    }()
    
    private lazy var confirmButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.title = R.string.localizable.commonConfirm(preferredLanguages: .currentLocale)
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.cornerRadius = .circle
        button.sora.horizontalOffset = 0
        button.sora.isEnabled = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.onConfirm?()
        }
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(containerView)
        
        containerView.addArrangedSubviews([
            headerLabel,
            sliderView,
            stackView,
            confirmButton
        ])
        
        containerView.setCustomSpacing(40, after: headerLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    private func setupHandlers() {
        sliderView.maxButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.maxButtonTapped()
        }
        
        sliderView.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }
    
    @objc
    private func sliderValueChanged(_ sender: UISlider) {
        set(sliderValue: sender.value)
    }
    
    private func maxButtonTapped() {
        set(sliderValue: 1.0)
    }
    
    private func set(sliderValue: Float) {
        guard let item else { return }
        
        let percentage = Double(sliderValue * 100)
        let formattedText = NumberFormatter.percent.stringFromDecimal(Decimal(percentage)) ?? ""
        let percentageText = localizationManager.isRightToLeft ? "%\(formattedText)" : "\(formattedText)%"
        
        sliderView.slider.value = sliderValue
        sliderView.maxButton.sora.isHidden = sliderValue < 1.0 ? false : true
        sliderView.percentageLabel.sora.text = percentageText
        
        if !item.isNeedInitialization {
            viewModel?.sharePercentage = Decimal(percentage)
        }
    }
}

extension EditFarmCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? EditFarmItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        self.item = item
        self.viewModel = item.viewModel
        
        if item.isNeedInitialization {
            set(sliderValue: item.viewModel.sharePercentage.floatValue / 100)
            item.isNeedInitialization = false
        }
        
        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let detailsViews = item.detailsViewModel.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.sora.isHidden = detailModel.rewardAssetImage == nil
            
            if let image = detailModel.rewardAssetImage {
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
