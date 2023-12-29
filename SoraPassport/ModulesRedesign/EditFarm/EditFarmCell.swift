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

final class EditFarmCell: SoramitsuTableViewCell {
    
    private let localizationManager = LocalizationManager.shared
    private var cancellables: Set<AnyCancellable> = []
    private let input: PassthroughSubject<Float, Never> = .init()
    
    private var item: EditFarmItem? {
        didSet {
            guard let item else { return }
            let output = item.service.transform(input: input.eraseToAnyPublisher())
            output
                .receive(on: DispatchQueue.main)
                .sink { event in }
                .store(in: &cancellables)
            
            item.service.$feeText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let self = self, let value else { return }
                    self.feeDetailView.valueLabel.sora.text = value
                }
                .store(in: &cancellables)
            
            item.service.$networkFeeAmount
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let self = self else { return }
                    self.networkFeeDetailView.valueLabel.sora.text = value
                    self.networkFeeDetailView.valueLabel.sora.loadingPlaceholder.type = value.isEmpty ? .shimmer : .none
                }
                .store(in: &cancellables)
            
            item.service.$buttonEnabled
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let self = self else { return }
                    self.confirmButton.sora.isUserInteractionEnabled = value
                    self.confirmButton.sora.backgroundColor = value ? .additionalPolkaswap : .bgSurfaceVariant
                    
                    let titleColor: SoramitsuColor = value ? .custom(uiColor: .white) : .fgTertiary
                    self.confirmButton.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                                                         fontData: FontType.buttonM,
                                                                         textColor: titleColor,
                                                                         alignment: .center)
                }
                .store(in: &cancellables)
        }
    }
    
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
        view.clipsToBounds = false
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
    
    private let yourPoolShareDetailView: DetailView = {
        var view = DetailView()
        view.assetImageView.sora.isHidden = true
        view.fiatValueLabel.sora.isHidden = true
        view.infoButton.sora.isHidden = true
        view.progressView.isHidden = true
        view.titleLabel.sora.text = R.string.localizable.polkaswapFarmingPoolShare(preferredLanguages: .currentLocale)
        return view
    }()
    
    private let yourPoolShareWillBeDetailView: DetailView = {
        var view = DetailView()
        view.assetImageView.sora.isHidden = true
        view.fiatValueLabel.sora.isHidden = true
        view.infoButton.sora.isHidden = true
        view.progressView.isHidden = true
        view.titleLabel.sora.text = R.string.localizable.polkaswapFarmingPoolShareWillBe(preferredLanguages: .currentLocale)
        return view
    }()
    
    private lazy var feeDetailView: DetailView = {
        var view = DetailView()
        view.assetImageView.sora.isHidden = true
        view.fiatValueLabel.sora.isHidden = true
        view.progressView.isHidden = true
        view.titleLabel.sora.text = R.string.localizable.commonFee(preferredLanguages: .currentLocale)
        view.infoButton.sora.isHidden = false
        view.infoButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.feeInfoHandler?()
        }
        return view
    }()
    
    private lazy var networkFeeDetailView: DetailView = {
        var view = DetailView()
        view.assetImageView.sora.isHidden = true
        view.fiatValueLabel.sora.isHidden = true
        view.progressView.isHidden = true
        view.titleLabel.sora.text = R.string.localizable.networkFee(preferredLanguages: .currentLocale)
        view.infoButton.sora.isHidden = false
        view.valueLabel.sora.loadingPlaceholder.type = .shimmer
        view.valueLabel.sora.text = ""
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        view.infoButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.networkFeeHandler?()
        }
        return view
    }()
    
    private lazy var confirmButton: SoramitsuButton = {
        let button = SoramitsuButton()
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

        let detailViews = [
            yourPoolShareDetailView,
            yourPoolShareWillBeDetailView,
            feeDetailView,
            networkFeeDetailView
        ]
        
        detailViews.enumerated().forEach { (index, detailView) in
            stackView.addArrangedSubviews(detailView)
            
            if index != detailViews.count - 1 {
                let separatorView = SoramitsuView()
                separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                separatorView.sora.backgroundColor = .bgPage
                stackView.addArrangedSubviews(separatorView)
            }
        }
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
        sliderView.slider.value = 1
        set(sliderValue: 1.0)
    }
    
    private func set(sliderValue: Float) {
        updateSliderView(with: sliderValue * 100)
    }
    
    private func updateSliderView(with sharePercentage: Float) {
//        let formattedText = NumberFormatter.percent.stringFromDecimal(sharePercentage) ?? ""
        let percentageText = localizationManager.isRightToLeft ? "%\(sharePercentage)" : "\(sharePercentage)%"
        
        sliderView.maxButton.sora.isHidden = sharePercentage.isZero ? false : true
        sliderView.percentageLabel.sora.text = percentageText

        yourPoolShareWillBeDetailView.valueLabel.sora.text = percentageText
        
        input.send(sharePercentage)
    }
}

extension EditFarmCell: CellProtocol {
    func set(item: ItemProtocol) {
        guard let item = item as? EditFarmItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        self.item = item
        
        sliderView.slider.value = item.stakedValue
        updateSliderView(with: item.stakedValue * 100)
        
        let formattedText = NumberFormatter.percent.stringFromDecimal(item.sharePercentage) ?? ""
        let percentageText = localizationManager.isRightToLeft ? "%\(formattedText)" : "\(formattedText)%"
        yourPoolShareDetailView.valueLabel.sora.text = percentageText
    }
}
