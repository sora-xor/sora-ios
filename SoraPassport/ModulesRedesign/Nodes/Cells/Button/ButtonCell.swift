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
