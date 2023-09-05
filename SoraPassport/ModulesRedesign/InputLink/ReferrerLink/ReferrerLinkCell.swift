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
import SoraFoundation
import SnapKit
import Combine


final class ReferrerLinkCell: SoramitsuTableViewCell {
    
    private var cancellables: Set<AnyCancellable> = []
    private weak var viewModel: ReferrerLinkViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            viewModel.$isEnabled
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.activateButton.sora.isEnabled = viewModel.isEnabled ?? false
                }
                .store(in: &cancellables)
        }
    }
    
    private lazy var containerView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.axis = .vertical
            $0.sora.distribution = .fill
            $0.sora.cornerRadius = .max
            $0.spacing = 24
            $0.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            $0.isLayoutMarginsRelativeArrangement = true
        }
    }()

    private lazy var descriptionLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.paragraphM
            $0.sora.numberOfLines = 0
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()

    private lazy var linkView: ReferrerLinkView = {
        let view = ReferrerLinkView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.textFieldDidChange()
        }
        return view
    }()

    private lazy var activateButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.backgroundColor = .accentPrimary
            $0.sora.cornerRadius = .extraLarge
            $0.sora.isEnabled = false
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.activeLinkTapped()
            }
        }
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
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none
        applyLocalization()
    }
    
    private func setupHierarchy() {
        contentView.addSubview(containerView)
        
        containerView.addArrangedSubviews([
            descriptionLabel,
            linkView,
            activateButton
        ])
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
        linkView.textField.becomeFirstResponder()
    }
    
    private func textFieldDidChange() {
        guard let viewModel = viewModel else { return }
        viewModel.userChangeTextField(with: linkView.textField.sora.text ?? "")
    }

    private func activeLinkTapped() {
        guard let viewModel = viewModel else { return }
        viewModel.userTappedOnActivate()
    }
}

extension ReferrerLinkCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? ReferrerLinkViewModel else { return }
        activateButton.sora.isEnabled = viewModel.isEnabled ?? false
        linkView.textField.sora.text = viewModel.address
        self.viewModel = viewModel
    }
}

extension ReferrerLinkCell: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        descriptionLabel.sora.text = R.string.localizable.referralReferrerDescription(preferredLanguages: languages)
        activateButton.sora.title = R.string.localizable.referralActivateButtonTitle(preferredLanguages: languages)
    }
}
