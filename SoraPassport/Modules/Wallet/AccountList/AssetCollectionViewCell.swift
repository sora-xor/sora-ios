import UIKit
import Foundation
import SoraUI
import CommonWallet
import Anchorage
import SoraFoundation

class AssetCollectionViewCell: UICollectionViewCell {
    
    let swipeEnabled = false

    @IBOutlet private var backView: UIView! {
        didSet {
            backgroundColor = R.color.neumorphism.base()
            backView.backgroundColor = R.color.neumorphism.base()
        }
    }
    @IBOutlet private var backgroundRoundedView: UIView! {
        didSet {
            setupSwipe()
        }
    }
    @IBOutlet private var symbolImageView: UIImageView!
    @IBOutlet private var accessoryLabel: UILabel!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    private(set) var assetViewModel: ConfigurableAssetViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()
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
        guard swipeEnabled else { return }
        
        backView.widthAnchor == UIScreen.main.bounds.size.width

        let containerView = UIView()
        containerView.addSubview(backView)

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

        backView.setNeedsLayout()
        backView.layoutIfNeeded()
    }

    private func setupGestureRecognizer() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hiddenContainerViewTapped))
        hiddenContainerView.addGestureRecognizer(tapGestureRecognizer)
        let visibleTap = UITapGestureRecognizer(target: self, action: #selector(visibleContainerViewTapped))
        backView.addGestureRecognizer(visibleTap)
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
                titleLabel.textColor = style.title.color
                titleLabel.font = style.title.font
                subtitleLabel.textColor = style.subtitle.color
                subtitleLabel.font = style.subtitle.font
                accessoryLabel.textColor = style.accessory.color
//                activityIndicator.tintColor = style.subtitle.color
                accessoryLabel.font = style.accessory.font
            }
        }
    }

    private func applyContent() {
        if let assetViewModel = assetViewModel {
            symbolImageView.isHidden = assetViewModel.imageViewModel == nil

            if let iconViewModel = assetViewModel.imageViewModel {
                iconViewModel.loadImage { [weak self] (icon, _) in
                    self?.symbolImageView.image = icon
                }
            }

            if let viewModel = assetViewModel as? ConfigurableAssetViewModel {
                toggleImageView.image = viewModel.toggleIcon
            }
            let amount = assetViewModel.amount
            let currentLocale = LocalizationManager.shared.selectedLocale

            titleLabel.attributedText = amount.prettyCurrency(baseFont: titleLabel.font, locale: currentLocale)
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
        if scrollView.contentOffset.x >= scrollView.contentSize.width/2 - 10 {
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
