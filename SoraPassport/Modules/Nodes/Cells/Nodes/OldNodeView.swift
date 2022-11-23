/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraFoundation
import SoraUI
import Anchorage

final class OldNodeView: UIControl {

    var onSelect: ((ChainNodeModel) -> Void)?
    var onCopy: ((ChainNodeModel) -> Void)?
    var onEdit: ((ChainNodeModel) -> Void)?
    var onRemove: ((ChainNodeModel) -> Void)?

    private var node: NodeViewModel?
    private lazy var interaction = UIContextMenuInteraction(delegate: self)

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1).withSize(15.0)
            $0.textColor = R.color.brandUltraBlack()
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var descriptionLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1).withSize(11.0)
            $0.textColor = R.color.neumorphism.brown()
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
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
            $0.setImage(R.image.iconEmptyDots(), for: .normal)
            $0.addTarget(self, action: #selector(onMoreTap), for: .touchUpInside)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(moreButton)

        titleLabel.do {
            $0.topAnchor == topAnchor
            $0.leadingAnchor == imageView.trailingAnchor + 21
            $0.trailingAnchor == moreButton.leadingAnchor
        }

        descriptionLabel.do {
            $0.topAnchor >= titleLabel.bottomAnchor + 4
            $0.leadingAnchor == titleLabel.leadingAnchor
            $0.trailingAnchor == titleLabel.trailingAnchor
            $0.bottomAnchor == bottomAnchor
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
        titleLabel.text = model.node.name
        descriptionLabel.text = model.node.url.absoluteString
        imageView.image = model.isSelected ? R.image.listCheckmarkIcon() : nil
        moreButton.isHidden = !model.isCustom
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

extension OldNodeView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
}
