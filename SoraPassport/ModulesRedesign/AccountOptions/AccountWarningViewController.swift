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

import Foundation
import SoraFoundation
import SoraUIKit
import Anchorage

final class AccountWarningViewController: SoramitsuViewController, ControllerBackedProtocol {

    enum WarningType {
        case passphrase
        case json
        case rawSeed
    }

    var completion: (() -> ())?

    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.layer.masksToBounds = true
            $0.sora.shadow = .default
        }
    }()

    private var stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 8
            $0.layer.cornerRadius = 0
            $0.sora.distribution = .fill
        }
    }()

    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    var submitButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.isEnabled = false
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(completeTapped), for: .touchUpInside)
        }
    }()

    init(warningType: WarningType) {
        self.warningType = warningType
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        configure()
    }

    private func configure() {
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.commonPayAttention(preferredLanguages: languages)

        switch warningType {
        case .passphrase:
            titleLabel.sora.text = R.string.localizable.exportProtectionPassphraseDescription(preferredLanguages: languages)
        case .rawSeed:
            titleLabel.sora.text = R.string.localizable.exportProtectionSeedDescription(preferredLanguages: languages)
        case .json:
            titleLabel.sora.text = R.string.localizable.exportProtectionJsonDescription(preferredLanguages: languages)
        }

        view.addSubview(containerView)

        let warnings: [String]

        switch warningType {
        case .passphrase:
            warnings = [
                R.string.localizable.exportProtectionPassphrase1(preferredLanguages: languages),
                R.string.localizable.exportProtectionPassphrase2(preferredLanguages: languages),
                R.string.localizable.exportProtectionPassphrase3(preferredLanguages: languages)
            ]
        case .rawSeed:
            warnings = [
                R.string.localizable.exportProtectionSeed1(preferredLanguages: languages),
                R.string.localizable.exportProtectionSeed2(preferredLanguages: languages),
                R.string.localizable.exportProtectionSeed3(preferredLanguages: languages)
            ]
        case .json:
            warnings = [
                R.string.localizable.exportProtectionJson1(preferredLanguages: languages),
                R.string.localizable.exportProtectionJson2(preferredLanguages: languages),
                R.string.localizable.exportProtectionJson3(preferredLanguages: languages)
            ]
        }

        stackView.removeArrangedSubviews()
        containerView.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubviews(
            warnings.map{
                CheckView(title: $0).then{
                    $0.addTapGesture { [weak self] recognizer in
                        self?.checkBoxTapped(sender: recognizer.view as? CheckView)
                    }
                }
            }
        )
        stackView.setCustomSpacing(24, after: stackView.arrangedSubviews.last!)
        stackView.addArrangedSubview(submitButton)
        stackView.setCustomSpacing(20, after: titleLabel)
        containerView.do {
            $0.horizontalAnchors == view.horizontalAnchors + 16
            $0.topAnchor == view.soraSafeTopAnchor

        }
        stackView.do {
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
            $0.verticalAnchors == containerView.verticalAnchors + 24
        }
    }

    var selectionCount = 0 {
        didSet {
            submitButton.sora.isEnabled = selectionCount == 3
        }
    }

    func checkBoxTapped(sender: CheckView?){
        guard let check = sender else { return }

        check.isSelected = !check.isSelected
        if check.isSelected {
            selectionCount += 1
        } else {
            selectionCount -= 1
        }
    }

    @objc
    func completeTapped(){
        completion?()
    }

    private let warningType: WarningType
}

extension AccountWarningViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        submitButton.sora.title = R.string.localizable.transactionContinue(preferredLanguages: languages)
    }
}

final class CheckView: SoramitsuView {

    private lazy var checkView: SoramitsuImageView = {
        SoramitsuImageView().then {
            $0.sora.borderColor = .fgPrimary
            $0.sora.cornerRadius = .circle
            $0.sora.clipsToBounds = true
            $0.sora.borderWidth = 1
            $0.clipsToBounds = true
        }

    }()

    private lazy var textLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.numberOfLines = 0
            $0.sora.lineBreakMode = .byWordWrapping
        }
    }()

    var isSelected: Bool = false {
        didSet {
            checkView.image = isSelected ? R.image.checkboxSelected() : nil
            checkView.sora.borderWidth = isSelected ? 0 : 1
            sora.borderColor = isSelected ? .accentPrimary : .bgSurfaceVariant
        }
    }
    

    init(title: String) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkView)
        addSubview(textLabel)

        sora.cornerRadius = .large
        sora.backgroundColor = .bgSurface
        sora.borderColor = isSelected ? .accentPrimary : .bgSurfaceVariant
        sora.borderWidth = 1

        self.heightAnchor >= 56

        checkView.do {
            $0.sizeAnchors == CGSize(width: 24, height: 24)
            $0.leadingAnchor == leadingAnchor + 16
            $0.centerYAnchor == centerYAnchor
        }

        textLabel.do {
            $0.verticalAnchors == verticalAnchors + 8
            $0.leadingAnchor == checkView.trailingAnchor + 16
            $0.trailingAnchor == trailingAnchor - 16
            $0.sora.text = title
            $0.sora.font = FontType.textS
            $0.sora.textColor = .fgPrimary
        }

    }
}
