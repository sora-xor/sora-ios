/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class ProjectDetailsViewController: UIViewController, AdaptiveDesignable {
    struct Constants {
        static let galleryCellSpacing: CGFloat = 19.0
        static let galleryHorizontalInsets: CGFloat = 20.0
        static let detailsCollapsedHeight: CGFloat = 172.0
        static let horizontalMinimumSpacing: CGFloat = 8.0
        static let rewardLableLeftWhenSuccess: CGFloat = 25.0
        static let rewardLableLeftWhenFail: CGFloat = 0.0
        static let voteButtonInsetsWhenOpen: CGFloat = 58.0
        static let voteButtonInsetsWhenFinished: CGFloat = 28.0
    }

	var presenter: ProjectDetailsPresenterProtocol!

    lazy var votesButtonFactory: VotesButtonFactoryProtocol.Type = VotesButtonFactory.self

    lazy var imageAppearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    lazy var detailsAppearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    lazy var changesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()
    lazy var favoriteAnimator: ViewAnimatorProtocol = SpringAnimator()

    private(set) var votesButton: RoundedButton!
    private(set) var votesButtonHeightConstraint: NSLayoutConstraint?
    private(set) var votesButtonWidthConstraint: NSLayoutConstraint?

    @IBOutlet private(set) var mainImageHeightConstraint: NSLayoutConstraint!

    @IBOutlet private(set) var scrollView: UIScrollView!
    @IBOutlet private(set) var mainImageView: UIImageView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var progressView: ProgressView!
    @IBOutlet private(set) var progressLabel: UILabel!
    @IBOutlet private(set) var deadlineLabel: UILabel!
    @IBOutlet private(set) var voteButton: RoundedButton!
    @IBOutlet private(set) var favoriteButton: RoundedButton!
    @IBOutlet private(set) var rewardView: UIView!
    @IBOutlet private(set) var rewardLabel: UILabel!
    @IBOutlet private(set) var rewardLabelLeading: NSLayoutConstraint!
    @IBOutlet private(set) var rewardImageView: UIImageView!
    @IBOutlet private(set) var statisticsView: BorderedContainerView!
    @IBOutlet private(set) var statisticsLabel: UILabel!
    @IBOutlet private(set) var detailsTextView: DetailsTextView!
    @IBOutlet private(set) var detailsTextViewHeight: NSLayoutConstraint!
    @IBOutlet private(set) var galleryLabel: UILabel!
    @IBOutlet private(set) var galleryCollectionView: UICollectionView!
    @IBOutlet private(set) var websiteButton: UIButton!
    @IBOutlet private(set) var emailButton: UIButton!

    @IBOutlet private(set) var progressLabelTrallingWhenLong: NSLayoutConstraint!
    @IBOutlet private(set) var progressLabelTrallingWhenShort: NSLayoutConstraint!
    @IBOutlet private(set) var deadlineLabelTopWhenLong: NSLayoutConstraint!
    @IBOutlet private(set) var deadlineLabelTopWhenShort: NSLayoutConstraint!
    @IBOutlet private(set) var deadlineLabelLeftWhenLong: NSLayoutConstraint!

    @IBOutlet private(set) var voteButtonTopWhenOpen: NSLayoutConstraint!
    @IBOutlet private(set) var voteButtonTopWhenFinished: NSLayoutConstraint!
    @IBOutlet private(set) var voteButtonLeftWhenShort: NSLayoutConstraint!
    @IBOutlet private(set) var voteButtonCenterWhenLong: NSLayoutConstraint!

    @IBOutlet private(set) var favoriteButtonCenterYWhenShort: NSLayoutConstraint!
    @IBOutlet private(set) var favoriteButtonTopWhenLong: NSLayoutConstraint!
    @IBOutlet private(set) var favoriteButtonTrallingWhenShort: NSLayoutConstraint!
    @IBOutlet private(set) var favoriteButtonCenterXWhenLong: NSLayoutConstraint!

    @IBOutlet private(set) var statisticsTopWithReward: NSLayoutConstraint!
    @IBOutlet private(set) var statisticsTopWithFavorite: NSLayoutConstraint!

    @IBOutlet private(set) var detailsTopWithStatistics: NSLayoutConstraint!
    @IBOutlet private(set) var detailsTopWithReward: NSLayoutConstraint!
    @IBOutlet private(set) var detailsTopWithFavorite: NSLayoutConstraint!

    @IBOutlet private(set) var galleryExpandedConstraint: NSLayoutConstraint!
    @IBOutlet private(set) var galleryCollapsedConstraint: NSLayoutConstraint!

    @IBOutlet private(set) var galleryCollectionViewHeightConstraint: NSLayoutConstraint!

    private(set) var viewModel: ProjectDetailsViewModelProtocol?

    private var isDetailsExpanded: Bool = false

    private(set) var mainImageSize = CGSize(width: 375.0, height: 213.0)
    private(set) var galleryCellSize = CGSize(width: 316.0, height: 220.0)

    var detailsExpandedHeight: CGFloat = 174.0
    var detailsCollapsedHeight: CGFloat = 174.0

    var contentWidth: CGFloat = 335.0
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 0.0, left: 20.0, bottom: 0.0, right: 20.0)

    // MARK: View

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTopBar()
        configureScrollView()
        configureDetailsView()
        configureGalleryCollectionView()
        adjustLayout()

        presenter.viewIsReady()
    }

    // MARK: Configuration

    private func adjustLayout() {
        mainImageSize.width *= designScaleRatio.width
        mainImageSize.height *= designScaleRatio.width

        galleryCellSize.width = floor(galleryCellSize.width * designScaleRatio.width)
        galleryCellSize.height = floor(galleryCellSize.height * designScaleRatio.width)

        mainImageHeightConstraint.constant = mainImageSize.height

        contentWidth *= designScaleRatio.width
        contentWidth += (designScaleRatio.width - 1.0) * (contentInsets.left + contentInsets.right)

        if isAdaptiveWidthDecreased {
            voteButton.contentInsets.top *= designScaleRatio.width
            voteButton.contentInsets.bottom *= designScaleRatio.width
            favoriteButton.contentInsets.top *= designScaleRatio.width
            favoriteButton.contentInsets.bottom *= designScaleRatio.width

            if let font = voteButton.imageWithTitleView?.titleFont {
                let fontSize = font.pointSize * designScaleRatio.width
                voteButton.imageWithTitleView?.titleFont = UIFont(name: font.fontName, size: fontSize)
            }

            if let font = favoriteButton.imageWithTitleView?.titleFont {
                let fontSize = font.pointSize * designScaleRatio.width
                favoriteButton.imageWithTitleView?.titleFont = UIFont(name: font.fontName, size: fontSize)
            }
        }

        if let galleryLayout = galleryCollectionView.collectionViewLayout as? MediaGalleryCollectionViewLayout {

            galleryCollectionViewHeightConstraint.constant = galleryCellSize.height

            galleryLayout.itemSize = galleryCellSize
            galleryLayout.minimumInteritemSpacing = Constants.galleryCellSpacing * designScaleRatio.width
            galleryLayout.minimumLineSpacing = Constants.galleryCellSpacing * designScaleRatio.width

            let pageWidth = galleryCellSize.width + galleryLayout.minimumInteritemSpacing
            galleryLayout.pageSize = CGSize(width: pageWidth,
                                            height: galleryCellSize.height)

            galleryLayout.sectionInset = UIEdgeInsets(top: 0.0,
                                                      left: Constants.galleryHorizontalInsets,
                                                      bottom: 0.0,
                                                      right: Constants.galleryHorizontalInsets)
        }
    }

    private func configureScrollView() {
        scrollView.alpha = 0.0
    }

    private func configureGalleryCollectionView() {
        galleryCollectionView.register(R.nib.mediaGalleryImageCollectionViewCell)
        galleryCollectionView.register(R.nib.mediaGalleryVideoCollectionViewCell)
        galleryCollectionView.decelerationRate = .fast
    }

    private func configureDetailsView() {
        detailsTextView.delegate = self
    }

    private func setupTopBar() {
        setupCloseButton()
        setupVotesButton()
    }

    private func setupVotesButton() {
        votesButton = votesButtonFactory.createBarVotesButton()
        votesButton.addTarget(self,
                              action: #selector(actionOpenVotes(sender:)),
                              for: .touchUpInside)

        updateVotesButtonConstraints()

        let voteBarItem = UIBarButtonItem(customView: votesButton)
        navigationItem.rightBarButtonItem = voteBarItem
    }

    private func setupCloseButton() {
        let closeBarItem = UIBarButtonItem(image: R.image.iconClose(),
                                           style: .plain,
                                           target: self,
                                           action: #selector(actionClose))
        navigationItem.leftBarButtonItem = closeBarItem
    }

    private func updateVotesButtonConstraints() {
        let size = votesButton.intrinsicContentSize

        if #available(iOS 11.0, *) {
            votesButtonHeightConstraint?.isActive = false
            votesButtonHeightConstraint = votesButton.heightAnchor.constraint(equalToConstant: size.height)
            votesButtonHeightConstraint?.isActive = true

            votesButtonWidthConstraint?.isActive = false
            votesButtonWidthConstraint = votesButton.widthAnchor.constraint(equalToConstant: size.width)
            votesButtonWidthConstraint?.isActive = true
        } else {
            var frame = votesButton.frame
            frame.size.width = size.width
            frame.size.height = size.height
            votesButton.frame = frame
        }
    }

    // MARK: Action

    @objc private func actionClose() {
        presenter.activateClose()
    }

    @objc private func actionOpenVotes(sender: AnyObject) {
        presenter.activateVotes()
    }

    @IBAction private func actionVote(sender: AnyObject) {
        guard let viewModel = viewModel else {
            return
        }

        _ = viewModel.delegate?.vote(for: viewModel)
    }

    @IBAction private func actionFavorite(sender: AnyObject) {
        guard let viewModel = viewModel, let delegate = viewModel.delegate else {
            return
        }

        if delegate.toggleFavorite(for: viewModel) {
            setFavorite(viewModel.isFavorite)

            favoriteAnimator.animate(view: favoriteButton, completionBlock: nil)
        }
    }

    @IBAction private func actionOpenWebsite(sender: AnyObject) {
        guard let viewModel = viewModel else {
            return
        }

        viewModel.delegate?.openWebsite(for: viewModel)
    }

    @IBAction private func actionWriteEmail(sender: AnyObject) {
        guard let viewModel = viewModel else {
            return
        }

        viewModel.delegate?.writeEmail(for: viewModel)
    }
}

extension ProjectDetailsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel?.galleryImageViewModels.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let galleryViewModel = viewModel!.galleryImageViewModels[indexPath.row]

        switch galleryViewModel {
        case .image(let viewModel):
            let mediaCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: R.reuseIdentifier.mediaImageCellId,
                for: indexPath)!

            mediaCell.bind(model: viewModel)

            return mediaCell
        case .video(let viewModel):
            let mediaCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: R.reuseIdentifier.mediaVideoCellId,
                for: indexPath)!

            mediaCell.bind(model: viewModel)

            return mediaCell
        }
    }
}

extension ProjectDetailsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let cell = collectionView.cellForItem(at: indexPath)

        presenter.activateGalleryItem(at: indexPath.row, animatedFrom: cell)
    }
}

extension ProjectDetailsViewController: DesignableNavigationBarProtocol {
    var separatorStyle: NavigationBarSeparatorStyle {
        return .empty
    }
}

extension ProjectDetailsViewController: ProjectDetailsViewProtocol {
    private func preprocess(projectDetails: ProjectDetailsViewModelProtocol) {
        if let mainImageViewModel = projectDetails.mainImageViewModel {
            mainImageViewModel.cornerRadius = 0.0
            mainImageViewModel.targetSize = mainImageSize
        }

        projectDetails.galleryImageViewModels.forEach { galleryModel in
            switch galleryModel {
            case .image(let model):
                model.cornerRadius = 0.0
                model.targetSize = self.galleryCellSize
            case .video(let model):
                model.preview?.cornerRadius = 0.0
                model.preview?.targetSize = self.galleryCellSize
            }

        }
    }

    func didReceive(projectDetails: ProjectDetailsViewModelProtocol) {
        preprocess(projectDetails: projectDetails)

        let optionalOldViewModel = viewModel
        viewModel = projectDetails

        if optionalOldViewModel == nil {
            applyChanges(since: optionalOldViewModel, animated: false)
            detailsAppearanceAnimator.animate(view: scrollView, completionBlock: nil)
        } else {
            applyChanges(since: optionalOldViewModel, animated: true)
        }
    }

    func didReceive(votes: String) {
        votesButton.imageWithTitleView?.title = votes
        votesButton.invalidateLayout()
        updateVotesButtonConstraints()
    }
}

extension ProjectDetailsViewController: DetailsTextViewDelegate {
    func didChangeExpandingState(in detailsView: DetailsTextView) {
        changesAnimator.animate(block: {
            self.detailsTextViewHeight.constant = detailsView.expanded ? self.detailsExpandedHeight
                : self.detailsCollapsedHeight
            self.view.layoutIfNeeded()
        }, completionBlock: nil)
    }
}
