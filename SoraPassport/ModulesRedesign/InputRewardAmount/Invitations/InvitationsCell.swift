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

import UIKit
import SoraUIKit
import SnapKit
import SoraFoundation

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
    private var currentInvitationCount: Decimal = Decimal(0) {
        didSet {
            amountView.textField.sora.text =  "\(currentInvitationCount)"
            amountView.underMinusLabel.sora.text =  "\(currentInvitationCount * fee) XOR"
            delegate?.userChanged(currentInvitationCount)
        }
    }
    private let localizationManager = LocalizationManager.shared
    
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
        currentInvitationCount = Decimal(string: text) ?? Decimal(0)
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
        button.sora.isEnabled = viewModel.isEnabled
        
        amountView.textField.becomeFirstResponder()
        amountView.underMinusLabel.sora.text = "\(viewModel.bondedAmount) \(viewModel.feeSymbol)"
        amountView.underPlusLabel.sora.text = R.string.localizable.commonBalance(preferredLanguages: .currentLocale) + ":\(viewModel.balance)"
        
        let invitationCount = (viewModel.bondedAmount / viewModel.fee).rounded(mode: .down)
        
        if invitationCount > 0 {
            amountView.textField.sora.text = "\(invitationCount)"
        }
        
        self.currentInvitationCount = invitationCount
        self.fee = viewModel.fee
        self.delegate = viewModel.delegate
    }
}
