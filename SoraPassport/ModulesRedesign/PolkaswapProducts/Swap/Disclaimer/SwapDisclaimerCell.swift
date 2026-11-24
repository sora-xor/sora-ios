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
    
    /// The flower over the title, so the sheet reads as Polkaswap before a word is read.
    private let flowerView: UIImageView = {
        let view = UIImageView(image: PortfolioGlyphs.flowerImage(size: 44))
        view.contentMode = .center
        view.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return view
    }()

    /// The rest of the disclaimer, one tap away: the sheet opens on its first paragraph only.
    private lazy var moreButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.title = R.string.localizable.showMore(preferredLanguages: .currentLocale)
        button.sora.rightImage = UIImage(systemName: "chevron.down",
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
        button.sora.imageSize = 12
        button.sora.addHandler(for: .touchUpInside) { [weak self] in self?.revealRest() }
        return button
    }()

    /// The first text's second paragraph, which waits behind Show more with the rest.
    private let text1RestLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    private var restViews: [UIView] { [text1RestLabel, text2Label, text3View, text4View, text5View, text6View] }

    private func revealRest() {
        let table = sequence(first: superview, next: { $0?.superview }).compactMap { $0 as? UITableView }.first
        let animated = !UIAccessibility.isReduceMotionEnabled
        restViews.forEach { $0.alpha = 0 }
        let reveal = {
            self.restViews.forEach { $0.isHidden = false }
            self.moreButton.isHidden = true
            self.stackView.layoutIfNeeded()
        }
        if let table, animated {
            table.performBatchUpdates { UIView.animate(withDuration: 0.3, animations: reveal) }
        } else {
            reveal()
            table?.performBatchUpdates(nil)
        }
        for (index, view) in restViews.enumerated() {
            UIView.animate(withDuration: animated ? 0.35 : 0, delay: animated ? 0.06 * Double(index) : 0) { view.alpha = 1 }
        }
    }

    private lazy var closeButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.primary))
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

        // The sheet opens on the paragraph with the FAQ, terms and privacy links; the rest is one tap away.
        let paragraphs = (text1Label.text ?? "").components(separatedBy: "\n\n")
        text1Label.text = paragraphs.first
        text1RestLabel.sora.text = paragraphs.dropFirst().joined(separator: "\n\n")
        stackView.addArrangedSubviews(flowerView, titleLabel, text1Label, moreButton,
                                      text1RestLabel, text2Label, text3View, text4View, text5View, text6View, closeButton)
        stackView.setCustomSpacing(8, after: flowerView)
        stackView.setCustomSpacing(34, after: text6View)
        stackView.setCustomSpacing(24, after: moreButton)
        restViews.forEach { $0.isHidden = true }

        decorate(label: text1Label)
        decorate(label: text6Label)
    }

    func decorate(label: NantesLabel) {
        label.delegate = self
        label.linkAttributes = [
            NSAttributedString.Key.foregroundColor: Lit.lacquerText
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

