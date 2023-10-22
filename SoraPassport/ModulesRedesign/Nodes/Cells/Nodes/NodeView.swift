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
import UIKit
import SoraFoundation
import SoraUI
import Anchorage
import SoraUIKit

final class NodeView: UIControl {

    var onSelect: ((ChainNodeModel) -> Void)?
    var onCopy: ((ChainNodeModel) -> Void)?
    var onEdit: ((ChainNodeModel) -> Void)?
    var onRemove: ((ChainNodeModel) -> Void)?

    private var node: NodeViewModel?
    private lazy var interaction = UIContextMenuInteraction(delegate: self)

    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private var descriptionLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textBoldXS
            $0.sora.textColor = .fgSecondary
            $0.numberOfLines = 0
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()



    private var imageView: UIImageView = {
        UIImageView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var moreButton: UIButton = {
        UIButton().then {
            $0.setImage(R.image.iconMenuVertical(), for: .normal)
            $0.addTarget(self, action: #selector(onMoreTap), for: .touchUpInside)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(moreButton)

        titleLabel.do {
            $0.topAnchor == topAnchor + 16
            $0.leadingAnchor == imageView.trailingAnchor + 21
            $0.trailingAnchor == moreButton.leadingAnchor
        }

        descriptionLabel.do {
            $0.topAnchor >= titleLabel.bottomAnchor + 4
            $0.leadingAnchor == titleLabel.leadingAnchor
            $0.trailingAnchor == titleLabel.trailingAnchor
            $0.bottomAnchor == bottomAnchor - 16
        }

        imageView.do {
            $0.centerYAnchor == centerYAnchor
            $0.leadingAnchor == leadingAnchor + 5
            $0.widthAnchor == 14
            $0.heightAnchor == 10
        }

        moreButton.do {
            $0.centerYAnchor == centerYAnchor
            $0.trailingAnchor == trailingAnchor
            $0.widthAnchor == 44
            $0.heightAnchor == 44
        }

        addTarget(self, action: #selector(userTapped), for: .touchUpInside)

        moreButton.addInteraction(interaction)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateView(model: NodeViewModel) {
        node = model
        titleLabel.sora.text = model.node.name
        descriptionLabel.sora.text = model.node.url.absoluteString
        imageView.image = model.isSelected ? R.image.listCheckmarkIcon() : nil
        moreButton.isHidden = !model.isCustom
        
        if model.isCustom {
            titleLabel.do {
                $0.trailingAnchor == moreButton.leadingAnchor
            }
        } else {
            titleLabel.do {
                $0.trailingAnchor == trailingAnchor
            }
        }
    }

    @objc
    func userTapped() {
        guard let node = node else { return }
        onSelect?(node.node)
    }

    @objc
    func onMoreTap() {
        interaction.perform(Selector("_presentMenuAtLocation:"), with: CGPoint.zero)
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        let favorite = UIAction(
            title: R.string.localizable.commonCopyAddress(preferredLanguages: .currentLocale),
            image: UIImage(systemName: "doc.on.doc.fill")
        ) { [unowned self] _ in
            guard let node = node else { return }
            onCopy?(node.node)
        }


        let share = UIAction(
            title: R.string.localizable.selectNodeCustomNodeEditNode(preferredLanguages: .currentLocale),
            image: UIImage(systemName: "pencil")
        ) { [unowned self] action in
            guard let node = node else { return }
            onEdit?(node.node)
        }

        let delete = UIAction(
            title: R.string.localizable.commonRemove(preferredLanguages: .currentLocale),
            image: UIImage(systemName: "trash.fill"),
            attributes: [.destructive]
        ) { [unowned self] action in
            guard let node = node else { return }
            onRemove?(node.node)
         }

         return UIContextMenuConfiguration(identifier: nil,
           previewProvider: nil) { _ in
           UIMenu(title: "", children: [favorite, share, delete])
         }
    }
}

extension NodeView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
}
