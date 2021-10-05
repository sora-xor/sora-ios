/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraUI
import CommonWallet
import Anchorage

final class AssetCollectionViewCell: UICollectionViewCell {
    private struct Constants {
        static let detailsSpacing: CGFloat = 8.0
    }

    @IBOutlet private var backgroundRoundedView: RoundedView! {
        didSet{
            setupSwipe()
        }
    }
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
        scrollView.contentOffset = .zero
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        return scrollView
    }()

    private let toggleImageView: UIImageView = {
        UIImageView()
    }()

    private let hiddenContainerView: UIView = {
        return UIView()
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .top
        return stackView
    }()

    private func setupSwipe() {
        let containerView = UIView()
        containerView.addSubview(backgroundRoundedView)
        let insets = UIEdgeInsets(top: 1, left: 20, bottom: 10, right: 20)
        backgroundRoundedView.edgeAnchors == containerView.edgeAnchors + insets

        hiddenContainerView.addSubview(toggleImageView)
        toggleImageView.centerAnchors == hiddenContainerView.centerAnchors

        stackView.addArrangedSubview(containerView)
        stackView.addArrangedSubview(hiddenContainerView)

        containerView.heightAnchor == stackView.heightAnchor
        hiddenContainerView.heightAnchor == stackView.heightAnchor

        addSubview(scrollView)
        scrollView.horizontalAnchors == scrollView.superview!.horizontalAnchors
        scrollView.verticalAnchors == scrollView.superview!.verticalAnchors
        scrollView.delegate = self
        scrollView.addSubview(stackView)
        stackView.horizontalAnchors == stackView.superview!.horizontalAnchors
        stackView.verticalAnchors == stackView.superview!.verticalAnchors
        stackView.heightAnchor == scrollView.heightAnchor
        stackView.widthAnchor == scrollView.widthAnchor * 2

        setupGestureRecognizer()
    }

    private func setupGestureRecognizer() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hiddenContainerViewTapped))
        hiddenContainerView.addGestureRecognizer(tapGestureRecognizer)
        let visibleTap = UITapGestureRecognizer(target: self, action: #selector(visibleContainerViewTapped))
        backgroundRoundedView.addGestureRecognizer(visibleTap)
    }

    @objc private func hiddenContainerViewTapped() {
        if let viewModel = assetViewModel as? ConfigurableAssetViewModel {
            try? viewModel.toggleCommand?.execute()
        } else {
            scrollView.contentOffset = .zero
        }
    }

    @objc private func visibleContainerViewTapped() {
        if let viewModel = assetViewModel as? ConfigurableAssetViewModel {
            try? viewModel.command?.execute()
        }
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
            if let viewModel = assetViewModel as? ConfigurableAssetViewModel {
                toggleImageView.image = viewModel.toggleIcon
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

extension AssetCollectionViewCell: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if(scrollView.contentOffset.x >= scrollView.contentSize.width/2 - 10){
            hiddenContainerViewTapped()
        }
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

