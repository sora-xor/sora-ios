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

import UIKit
import SoraUIKit
import SnapKit
import SoraFoundation
import Combine

protocol InvitationsCellDelegate: AlertPresentable {
    func isMinusEnabled(_ currentInvitationCount: Decimal) -> Bool
    func isPlusEnabled(_ currentInvitationCount: Decimal) -> Bool
    func userChanged(_ currentInvitationCount: Decimal)
    func networkFeeInfoButtonTapped()
    func buttonTapped()
}

final class InvitationsCell: SoramitsuTableViewCell {
    
    private enum Constants {
        static let smallSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
    }
    
    private weak var delegate: InvitationsCellDelegate?
    
    private var fee: Decimal = Decimal(0)
    private var feeSymbol = "XOR"
    private var currentInvitationCount: Decimal = Decimal(0) {
        didSet {
            amountView.textField.sora.text =  "\(currentInvitationCount)"
            amountView.underMinusLabel.sora.text =  "\(currentInvitationCount * fee) \(feeSymbol)"
            delegate?.userChanged(currentInvitationCount)
        }
    }
    private let localizationManager = LocalizationManager.shared
    
    private var cancellables: Set<AnyCancellable> = []
    private weak var viewModel: InvitationsViewModel? {
        didSet {
            cancellables.removeAll()
            guard let viewModel else { return }
            viewModel.$isEnabled
                .receive(on: DispatchQueue.main)
                .sink { [weak self] enabled in
                    guard let self = self else { return }
                    self.button.sora.isEnabled = enabled ?? false
                }
                .store(in: &cancellables)
        }
    }
    
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        label.sora.numberOfLines = 0
        return label
    }()
    
    private lazy var descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        label.sora.numberOfLines = 0
        return label
    }()
    
    private lazy var amountView: AmountView = {
        let view = AmountView()
        return view
    }()
    
    private lazy var feeView: FeeView = {
        let view = FeeView()
        return view
    }()
    
    private lazy var button: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.buttonTapped()
        }
        return button
    }()
    
    private lazy var stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.sora.backgroundColor = .bgSurface
        stackView.sora.cornerRadius = .max
        stackView.sora.cornerMask = .all
        stackView.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupCell() {
        sora.selectionStyle = .none
        sora.backgroundColor = .custom(uiColor: .clear)
        configure()
    }
    
    private func setupHierarchy() {
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubviews([
            titleLabel,
            descriptionLabel,
            amountView,
            feeView,
            button
        ])
    }
    
    private func setupLayout() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
        
        stackView.setCustomSpacing(Constants.smallSpacing, after: titleLabel)
        stackView.setCustomSpacing(Constants.largeSpacing, after: descriptionLabel)
        stackView.setCustomSpacing(Constants.smallSpacing, after: amountView)
        stackView.setCustomSpacing(Constants.largeSpacing, after: feeView)
    }
    
    private func configure() {
        amountView.minusButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.minusTapped()
        }
        
        amountView.plusButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.plusTapped()
        }
        
        amountView.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.textFieldChanged()
        }
        
        feeView.infoButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.networkFeeInfoButtonTapped()
        }
    }
    
    private func buttonTapped() {
        guard viewModel?.isEnabled == true else { return }
        delegate?.buttonTapped()
    }
    
    private func plusTapped() {
        guard delegate?.isPlusEnabled(currentInvitationCount) == true else { return }
        currentInvitationCount += 1
    }

    private func minusTapped() {
        guard delegate?.isMinusEnabled(currentInvitationCount) == true else { return }
        currentInvitationCount -= 1
    }

    private func textFieldChanged() {
        let text = amountView.textField.sora.text ?? "0"
        let isWholeNumber = text.range(of: #"[0-9]+\z"#, options: [.regularExpression, .anchored]) != nil
        currentInvitationCount = isWholeNumber ? (AmountDecimal(string: text)?.decimalValue ?? 0) : 0
    }
    
    private func networkFeeInfoButtonTapped() {
        delegate?.networkFeeInfoButtonTapped()
    }
}

extension InvitationsCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? InvitationsViewModel else { return }
        titleLabel.sora.text = viewModel.title
        descriptionLabel.sora.text = viewModel.description
        feeView.feeLabel.sora.text = "\(viewModel.fee) \(viewModel.feeSymbol)"
        button.sora.title = viewModel.buttonTitle
        button.sora.isEnabled = viewModel.isEnabled ?? false
        
        amountView.textField.becomeFirstResponder()
        amountView.underMinusLabel.sora.text = "\(viewModel.bondedAmount) \(viewModel.feeSymbol)"
        amountView.underPlusLabel.sora.text = R.string.localizable.commonBalance(preferredLanguages: .currentLocale) + ":\(viewModel.balance)"
        
        let invitationCount = viewModel.fee > 0 && viewModel.bondedAmount >= 0
            ? (viewModel.bondedAmount / viewModel.fee).rounded(mode: .down) : 0
        self.fee = viewModel.fee
        self.feeSymbol = viewModel.feeSymbol
        self.delegate = viewModel.delegate
        self.viewModel = viewModel
        self.currentInvitationCount = invitationCount
    }
}
