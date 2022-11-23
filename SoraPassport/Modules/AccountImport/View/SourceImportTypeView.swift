/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraUI
import Anchorage
import SoraFoundation

final class SourceImportTypeView: UIControl {

    private var titleLabel: UILabel = {
        UILabel().then {
            let preferredLocalizations = LocalizationManager.shared.preferredLocalizations
            
            $0.text = R.string.localizable.recoverySourceType1(preferredLanguages: preferredLocalizations)
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    private var valueLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.neumorphism.borderBase()
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    private var arrowImageView: UIImageView = {
        UIImageView(image: R.image.arrowDown()).then {
            $0.widthAnchor == 12
            $0.heightAnchor == 8
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }
    
    func setupValueText(with text: String) {
        valueLabel.text = text
    }

    private func configure() {
        addSubview(titleLabel)
        addSubview(arrowImageView)
        addSubview(valueLabel)

        titleLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.topAnchor == topAnchor
        }
        
        titleLabel.font = UIFont.styled(for: .paragraph1)
        
        arrowImageView.do {
            $0.leadingAnchor == titleLabel.trailingAnchor + 8
            $0.centerYAnchor == titleLabel.centerYAnchor
        }
        
        valueLabel.do {
            $0.bottomAnchor == bottomAnchor
            $0.centerXAnchor == centerXAnchor
        }
        valueLabel.font = UIFont.styled(for: .title1)
    }
}
