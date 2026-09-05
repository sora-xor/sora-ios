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

    private let scrollView = UIScrollView()

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
            $0.sora.dynamicTextStyle = .body
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private lazy var submitButton: UIButton = {
        let button = WalletUX.button(R.string.localizable.transactionContinue(preferredLanguages: languages), primary: true) { [weak self] in self?.completeTapped() }
        button.isEnabled = false
        return button
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

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

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
                    let check = $0
                    check.onActivate = { [weak self, weak check] in self?.checkBoxTapped(sender: check) }
                    check.addTapGesture { [weak check] _ in check?.onActivate?() }
                }
            }
        )
        stackView.setCustomSpacing(24, after: stackView.arrangedSubviews.last!)
        stackView.addArrangedSubview(submitButton)
        stackView.setCustomSpacing(20, after: titleLabel)
        stackView.do {
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
            $0.verticalAnchors == containerView.verticalAnchors + 24
        }
    }

    var selectionCount = 0 {
        didSet {
            submitButton.isEnabled = selectionCount == 3
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
        guard selectionCount == 3 else { return }
        completion?()
    }

    private let warningType: WarningType
}

extension AccountWarningViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        submitButton.configuration?.title = R.string.localizable.transactionContinue(preferredLanguages: languages)
    }
}

final class CheckView: SoramitsuView {
    var onActivate: (() -> Void)?
    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }

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
            accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }
    

    init(title: String) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button

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
            $0.sora.dynamicTextStyle = .body
            $0.sora.textColor = .fgPrimary
        }

    }
}
