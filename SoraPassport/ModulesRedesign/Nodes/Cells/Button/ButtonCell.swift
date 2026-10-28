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
import Then
import Anchorage

protocol ButtonCellDelegate {
    func buttonTapped()
}

final class ButtonCell: UITableViewCell {

    private var delegate: ButtonCellDelegate?

    // MARK: - Outlets
    private lazy var button: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.backgroundColor = .additionalPolkaswap
            $0.sora.cornerRadius = .circle
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.buttonTapped()
            }
        }
    }()

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    func buttonTapped() {
        delegate?.buttonTapped()
    }
}

extension ButtonCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let model = viewModel as? ButtonViewModelProtocol else { return }
        button.sora.title = model.title
        button.sora.isEnabled = model.isEnabled
        self.delegate = model.delegate
    }
}

private extension ButtonCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(button)

        button.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.heightAnchor == 56
            $0.bottomAnchor == contentView.bottomAnchor
        }
    }
}
