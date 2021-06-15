/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraUI
import CommonWallet

final class AssetCollectionViewCell: UICollectionViewCell {
    private struct Constants {
        static let detailsSpacing: CGFloat = 8.0
    }

    @IBOutlet private var backgroundRoundedView: RoundedView!
    @IBOutlet private var leftRoundedView: RoundedView!
    @IBOutlet private var symbolLabel: UILabel!
    @IBOutlet private var symbolImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var accessoryLabel: UILabel!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private var subtitleLabelLeading: NSLayoutConstraint!
    @IBOutlet private var detailIconView: UIImageView!
    @IBOutlet private var detailIconWidth: NSLayoutConstraint!
    @IBOutlet private var detailIconHeight: NSLayoutConstraint!

    private(set) var assetViewModel: ConfigurableAssetViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()
        activityIndicator.hidesWhenStopped = true
        prepareViewModelReplacement()

        assetViewModel = nil
    }

    private func applyStyle() {
        if let assetViewModel = assetViewModel {
            switch assetViewModel.style {
            case .card(let style):
                backgroundRoundedView.fillColor = style.backgroundColor
                backgroundRoundedView.cornerRadius = style.cornerRadius
                backgroundRoundedView.shadowColor = style.shadow.color
                backgroundRoundedView.shadowOffset = style.shadow.offset
                backgroundRoundedView.shadowOpacity = style.shadow.opacity
                backgroundRoundedView.shadowRadius = style.shadow.blurRadius
                leftRoundedView.fillColor = style.leftFillColor
                leftRoundedView.cornerRadius = style.cornerRadius
                symbolLabel.textColor = style.symbol.color
                symbolLabel.font = style.symbol.font
                titleLabel.textColor = style.title.color
                titleLabel.font = style.title.font
                subtitleLabel.textColor = style.subtitle.color
                subtitleLabel.font = style.subtitle.font
                accessoryLabel.textColor = style.accessory.color
                activityIndicator.tintColor = style.subtitle.color
                accessoryLabel.font = style.accessory.font
            }
        }
    }

    private func applyContent() {
        if let assetViewModel = assetViewModel {
            symbolLabel.isHidden = assetViewModel.imageViewModel != nil
            symbolImageView.isHidden = assetViewModel.imageViewModel == nil

            if let iconViewModel = assetViewModel.imageViewModel {
                iconViewModel.loadImage { [weak self] (icon, _) in
                    self?.symbolImageView.image = icon
                }
            } else {
                symbolLabel.text = assetViewModel.symbol
            }

            titleLabel.text = assetViewModel.amount
            subtitleLabel.text = assetViewModel.details
            accessoryLabel.text = assetViewModel.accessoryDetails
        }
    }

    private func prepareViewModelReplacement() {
        assetViewModel?.imageViewModel?.cancel()
    }
}

extension AssetCollectionViewCell: WalletViewProtocol {
    var viewModel: WalletViewModelProtocol? {
        return assetViewModel
    }

    func bind(viewModel: WalletViewModelProtocol) {
        prepareViewModelReplacement()

        guard let assetViewModel = viewModel as? ConfigurableAssetViewModelProtocol else {
            return
        }

        self.assetViewModel = assetViewModel

        applyStyle()
        applyContent()

        setNeedsLayout()
    }
}

