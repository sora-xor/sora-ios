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

import SoraUIKit
import UIKit

final class ConfirmAssetsCell: SoramitsuTableViewCell {
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fillEqually
        view.spacing = 8
        view.sora.clipsToBounds = false
        return view
    }()
    
    private let firstAsset: ConfirmAssetView = {
        let view = ConfirmAssetView()
        view.sora.cornerRadius = .max
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        return view
    }()
    
    private let secondAsset: ConfirmAssetView = {
        let view = ConfirmAssetView()
        view.sora.cornerRadius = .max
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        return view
    }()

    private let operationImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.backgroundColor = .bgSurface
        return view
    }()
    

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        stackView.addArrangedSubviews(firstAsset, secondAsset)
        contentView.addSubviews(stackView, operationImageView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            operationImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            operationImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            operationImageView.widthAnchor.constraint(equalToConstant: 24),
            operationImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
}

extension ConfirmAssetsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ConfirmAssetsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        item.firstAssetImageModel.imageViewModel?.loadImage { [weak self] (icon, _) in
            self?.firstAsset.imageView.image = icon
        }
        
        item.secondAssetImageModel.imageViewModel?.loadImage { [weak self] (icon, _) in
            self?.secondAsset.imageView.image = icon
        }

        firstAsset.symbolLabel.sora.text = item.firstAssetImageModel.symbol
        firstAsset.amountLabel.sora.text = item.firstAssetImageModel.amountText
        
        secondAsset.symbolLabel.sora.text = item.secondAssetImageModel.symbol
        secondAsset.amountLabel.sora.text = item.secondAssetImageModel.amountText
        
        operationImageView.image = UIImage(named: item.operationImageName)
    }
}

