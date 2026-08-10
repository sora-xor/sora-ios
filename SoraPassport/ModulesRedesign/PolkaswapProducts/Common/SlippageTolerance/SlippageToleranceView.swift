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
import SoraUIKit
import UIKit

/// Exact slippage used by every legacy Polkaswap quote and signed limit.
///
/// A percent is stored as basis points so values never pass through Float/Double.
/// Context parsing intentionally accepts legacy canonical decimal forms such as
/// `0.50` and `1.0`, while all new writes use `contextValue`.
struct PolkaswapSlippage: Equatable, Sendable {
    static let defaultValue = PolkaswapSlippage(uncheckedBasisPoints: 50)
    static let maximumBasisPoints: UInt16 = 1_000

    let basisPoints: UInt16

    init?(basisPoints: UInt16) {
        guard (1...Self.maximumBasisPoints).contains(basisPoints) else {
            return nil
        }
        self.basisPoints = basisPoints
    }

    init?(percent: Decimal) {
        guard percent > 0, percent <= 10 else {
            return nil
        }

        var scaled = percent * 100
        var integral = Decimal()
        NSDecimalRound(&integral, &scaled, 0, .plain)
        guard integral == scaled else {
            return nil
        }

        let rawValue = NSDecimalNumber(decimal: integral).uint64Value
        guard rawValue <= UInt64(Self.maximumBasisPoints) else {
            return nil
        }
        self.init(basisPoints: UInt16(rawValue))
    }

    init?(contextValue: String) {
        guard contextValue.range(
            of: #"^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,2})?$"#,
            options: .regularExpression
        ) != nil,
        let percent = Decimal(string: contextValue, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        self.init(percent: percent)
    }

    var percent: Decimal {
        Decimal(Int(basisPoints)) / 100
    }

    var fraction: Decimal {
        Decimal(Int(basisPoints)) / 10_000
    }

    var contextValue: String {
        let whole = Int(basisPoints) / 100
        let remainder = Int(basisPoints) % 100
        if remainder == 0 {
            return "\(whole)"
        }
        if remainder.isMultiple(of: 10) {
            return "\(whole).\(remainder / 10)"
        }
        return "\(whole).\(remainder < 10 ? "0" : "")\(remainder)"
    }

    var displayValue: String {
        "\(contextValue)%"
    }

    func minimumAmount(for amount: Decimal) -> Decimal {
        amount * Decimal(10_000 - Int(basisPoints)) / 10_000
    }

    func maximumAmount(for amount: Decimal) -> Decimal {
        amount * Decimal(10_000 + Int(basisPoints)) / 10_000
    }

    private init(uncheckedBasisPoints: UInt16) {
        basisPoints = uncheckedBasisPoints
    }
}

protocol SlippageToleranceViewDelegate: AnyObject {
    func slippageToleranceChanged(_ to: PolkaswapSlippage?)
}

final class SlippageToleranceView: SoramitsuView {

    var delegate: SlippageToleranceViewDelegate?

    let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.alignment = .fill
        view.sora.distribution = .fill
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.spacing = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    public lazy var field: InputField = {
        let field = InputField()
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        field.textField.returnKeyType = .done
        field.textField.tag = TextFieldTag.name.rawValue
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textField.delegate = self
        field.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            guard let self = self else { return }
            
            let rawValue = self.field.textField.text?
                .replacingOccurrences(of: "%", with: "", options: .literal, range: nil)
                .replacingOccurrences(of: ",", with: ".", options: .literal, range: nil) ?? ""
            var currentValue = PolkaswapSlippage(contextValue: rawValue)
            
            if (self.field.textField.text?.contains("%") ?? false) {
                self.field.textField.sora.text?.removeLast()
            }

            if let decimalValue = Decimal(
                string: rawValue,
                locale: Locale(identifier: "en_US_POSIX")
            ), decimalValue > 10 {
                self.field.textField.sora.text = "10"
                currentValue = PolkaswapSlippage(contextValue: "10")
            }
            
            if let text = self.field.textField.text {
                self.field.sora.text = "\(text)%"
            }
            
            self.delegate?.slippageToleranceChanged(currentValue)
        }
        field.textField.autocorrectionType = .no
        return field
    }()
    
    public let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.text = R.string.localizable.polkaswapSlippageInfo(preferredLanguages: .currentLocale)
        return label
    }()
    
    public lazy var slipageButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.horizontalOffset = 12
        button.sora.cornerRadius = .circle
        button.sora.title = R.string.localizable.commonDone(preferredLanguages: .currentLocale)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
        }
        return button
    }()
    
    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: .clear)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        stackView.addArrangedSubviews(field, descriptionLabel, slipageButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

extension SlippageToleranceView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        //INFO: on x86_64 architecture it called twice and make crash of app in didReceiveReplacement method. Added for autotests
        #if (arch(x86_64))
            return true
        #endif

        return percentageLimit(textField: textField, string: string)
    }
    
    private func percentageLimit(textField: UITextField, string: String) -> Bool {
        let dotString = "."
        let commaString = ","

        guard let text = textField.text, text != dotString, text != commaString else { return false }

        if text.isEmpty && (string == dotString || string == commaString) { return false }

        let isDeleteKey = string.isEmpty

        if !isDeleteKey {
            if text.contains(dotString) {
                if text.components(separatedBy: dotString)[1].count == 2 || string == dotString {
                    return false
                }
            }
            if text.contains(commaString) {
                if text.components(separatedBy: commaString)[1].count == 2 || string == commaString {
                    return false
                }
            }
        }

        return true
    }
}
