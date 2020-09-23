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
            accessoryLabel.text = assetViewModel.accessoryDetails

            updateSubtitleForDetails(assetViewModel.details, status: assetViewModel.status)
        }
    }

    private func updateSubtitleForDetails(_ details: String, status: ConfigurableAssetStatus) {
        subtitleLabel.text = details

        if status == .failed, let errorIcon = R.image.iconFailure() {
            detailIconWidth.constant = errorIcon.size.width
            detailIconHeight.constant = errorIcon.size.height
            detailIconView.image = errorIcon
        } else {
            detailIconWidth.constant = 0.0
            detailIconHeight.constant = 0.0
            detailIconView.image = nil
        }

        var leadingOffset: CGFloat = detailIconWidth.constant

        if status == .inProgress {
            activityIndicator.startAnimating()
            leadingOffset = activityIndicator.intrinsicContentSize.width
        } else {
            activityIndicator.stopAnimating()
        }

        if leadingOffset > 0.0 {
            leadingOffset += Constants.detailsSpacing
        }

        subtitleLabelLeading.constant = leadingOffset
    }

    private func prepareViewModelReplacement() {
        assetViewModel?.delegate = nil
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

        assetViewModel.delegate = self

        applyStyle()
        applyContent()

        setNeedsLayout()
    }
}

extension AssetCollectionViewCell: ConfigurableAssetViewModelDelegate {
    func viewModelDidChangeStatus(_ viewModel: ConfigurableAssetViewModelProtocol,
                                  oldStatus: ConfigurableAssetStatus) {
        updateSubtitleForDetails(viewModel.details, status: viewModel.status)
    }
}
