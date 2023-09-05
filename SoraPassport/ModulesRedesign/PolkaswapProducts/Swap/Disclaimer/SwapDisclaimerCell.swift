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
import Nantes

final class SwapDisclaimerCell: SoramitsuTableViewCell {
    
    private var poolDetailsItem: SwapDisclaimerItem?
    let linkDecorator = LinkDecoratorFactory.disclaimerDecorator()
    
    private var item: SwapDisclaimerItem?
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.shadow = .small
        view.spacing = 20
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 32, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.polkaswapInfoTitle(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        return label
    }()
    
    public let text1Label: NantesLabel = {
        let label = NantesLabel()
        label.numberOfLines = 0
        label.text = R.string.localizable.polkaswapInfoText1(preferredLanguages: .currentLocale)
        return label
    }()
    
    public let text2Label: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.polkaswapInfoText2(preferredLanguages: .currentLocale)
        label.sora.numberOfLines = 0
        return label
    }()
    
    public let text3View: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        view.spacing = 5
        view.sora.alignment = .leading
        return view
    }()
    
    public let text3NumberLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = "1."
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    public let text3Label: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.polkaswapInfoText3(preferredLanguages: .currentLocale)
        label.sora.numberOfLines = 0
        return label
    }()
    
    public let text4View: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        view.spacing = 5
        view.sora.alignment = .leading
        return view
    }()
    
    public let text4NumberLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = "2."
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    public let text4Label: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.polkaswapInfoText4(preferredLanguages: .currentLocale)
        label.sora.numberOfLines = 0
        return label
    }()
    
    public let text5View: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        view.spacing = 5
        view.sora.alignment = .leading
        return view
    }()
    
    public let text5NumberLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = "3."
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    public let text5Label: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.polkaswapInfoText5(preferredLanguages: .currentLocale)
        label.sora.numberOfLines = 0
        return label
    }()
    
    public let text6View: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        view.spacing = 16
        return view
    }()
    
    public let text6UnderlineView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .fgPrimary
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }()
    
    public let text6Label: NantesLabel = {
        let label = NantesLabel()
        label.text = R.string.localizable.polkaswapInfoText6(preferredLanguages: .currentLocale)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var closeButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .tonal(.primary))
        button.sora.horizontalOffset = 0
        button.sora.title = R.string.localizable.commonClose(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.closeButtonHandler?()
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
        contentView.addSubview(stackView)
        
        text3View.addArrangedSubviews(text3NumberLabel, text3Label)
        text4View.addArrangedSubviews(text4NumberLabel, text4Label)
        text5View.addArrangedSubviews(text5NumberLabel, text5Label)
        text6View.addArrangedSubviews(text6UnderlineView, text6Label)

        stackView.addArrangedSubviews(titleLabel, text1Label, text2Label, text3View, text4View, text5View, text6View, closeButton)
        stackView.setCustomSpacing(34, after: text6View)

        decorate(label: text1Label)
        decorate(label: text6Label)
    }

    func decorate(label: NantesLabel) {
        label.delegate = self
        label.linkAttributes = [
            NSAttributedString.Key.foregroundColor: R.color.brandPolkaswapPink()!
        ]
        var text = label.text ?? ""
        let links: [(URL, NSRange)] = linkDecorator.links(inText: &text)
        
        let attributedText = SoramitsuTextItem(text: text,
                                     fontData: FontType.paragraphM,
                                     textColor: .fgPrimary,
                                     alignment: .left).attributedString
        
        label.attributedText = attributedText
        for link in links {
            label.addLink(to: link.0, withRange: link.1)
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            text6UnderlineView.topAnchor.constraint(equalTo: text6Label.topAnchor),
            text6UnderlineView.bottomAnchor.constraint(equalTo: text6Label.bottomAnchor),
        ])
    }
}

extension SwapDisclaimerCell: NantesLabelDelegate {
    func attributedLabel(_ label: NantesLabel, didSelectLink link: URL) {
        UIApplication.shared.open(link, options: [:], completionHandler: nil)
    }
}

extension SwapDisclaimerCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? SwapDisclaimerItem else {
            assertionFailure("Incorect type of item")
            return
        }

        self.item = item
    }
}

