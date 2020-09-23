/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

final class ReferendumCollectionViewCell: AnimatableCollectionView, Localizable {
    lazy var imageAppearanceAnimator: ViewAnimatorProtocol = TransitionAnimator(type: .fade)

    @IBOutlet private(set) var backgroundRoundedView: RoundedView!
    @IBOutlet private(set) var imageView: UIImageView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var descriptionLabel: UILabel!
    @IBOutlet private(set) var bottomSeparator: BorderedContainerView!
    @IBOutlet private(set) var remainedTitleLabel: UILabel!
    @IBOutlet private(set) var remainedDetailsLabel: UILabel!
    @IBOutlet private(set) var progressView: ProgressView!
    @IBOutlet private(set) var progressSeparatorView: UIView!
    @IBOutlet private(set) var supportTitleLabel: UILabel!
    @IBOutlet private(set) var unsupportTitleLabel: UILabel!
    @IBOutlet private(set) var supportVotesImageView: UIImageView!
    @IBOutlet private(set) var unsupportVotesImageView: UIImageView!
    @IBOutlet private(set) var supportVotesLabel: UILabel!
    @IBOutlet private(set) var unsupportVotesLabel: UILabel!
    @IBOutlet private(set) var leftTouchArea: RoundedButton!
    @IBOutlet private(set) var rightTouchArea: RoundedButton!

    private var viewModel: ReferendumViewModelProtocol?
    private var layoutMetadata: ReferendumLayoutMetadata?

    // MARK: Internal Management

    override func awakeFromNib() {
        super.awakeFromNib()

        setupLocalization()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.imageViewModel?.cancel()
        imageView.image = nil

        viewModel?.remainedTimeViewModel?.stop()
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations

        supportTitleLabel.text = R.string.localizable
            .referendumSupportTitle(preferredLanguages: languages)

        unsupportTitleLabel.text = R.string.localizable
            .referendumUnsupportTitle(preferredLanguages: languages)

        updateRemainedTime()
    }

    func applyLocalization() {
        setupLocalization()

        if superview != nil {
            setNeedsLayout()
        }
    }

    // MARK: View Model Setup

    func bind(viewModel: ReferendumViewModelProtocol,
              layoutMetadata: ReferendumLayoutMetadata) {
        self.viewModel = viewModel
        self.layoutMetadata = layoutMetadata

        backgroundRoundedView.cornerRadius = layoutMetadata.cornerRadius

        titleLabel.text = viewModel.content.title
        descriptionLabel.text = viewModel.content.details

        progressView.setProgress(CGFloat(viewModel.content.votingProgress),
                                 animated: false)

        supportVotesLabel.text = viewModel.content.supportingVotes
        unsupportVotesLabel.text = viewModel.content.unsupportingVotes

        leftTouchArea.isUserInteractionEnabled = !viewModel.content.finished
        rightTouchArea.isUserInteractionEnabled = !viewModel.content.finished

        updateImage()

        viewModel.remainedTimeViewModel?.start(self)

        updateRemainedTime()

        setNeedsLayout()
    }

    private func updateImage() {
        if let image = viewModel?.imageViewModel?.image {
            imageView.image = image
            return
        }

        viewModel?.imageViewModel?.loadImage { [weak self] (image, error) in
            guard error == nil else {
                return
            }

            guard let strongSelf = self else {
                return
            }

            strongSelf.imageView.image = image
            strongSelf.imageAppearanceAnimator.animate(view: strongSelf.imageView,
                                                       completionBlock: nil)
        }
    }

    private func updateRemainedTime() {
        guard let viewModel = viewModel else {
            return
        }

        let locale = localizationManager?.selectedLocale

        if let remainedTime = viewModel.remainedTimeViewModel?.remainedSeconds {
            if remainedTime > 0.0 {
                remainedTitleLabel.text = R.string.localizable
                    .referendumEndsInTitle(preferredLanguages: locale?.rLanguages)
                remainedDetailsLabel.text = viewModel.remainedTimeViewModel?.titleForLocale(locale)
            } else {
                remainedTitleLabel.text = viewModel.remainedTimeViewModel?.titleForLocale(locale)
                remainedDetailsLabel.text = ""
            }
        } else {
            remainedTitleLabel.text = R.string.localizable
                .referendumEndedTitle(preferredLanguages: locale?.rLanguages)
            remainedDetailsLabel.text = viewModel.content.remainedTimeDetails
        }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        guard
            let layout = viewModel?.layout,
            let metadata = layoutMetadata else {
            return
        }

        var origin = CGPoint(x: 0.0, y: 0.0)

        layoutImage(at: &origin, layout: layout, metadata: metadata)

        origin.y += metadata.contentInsets.top
        origin.x = metadata.contentInsets.left

        layoutRemainedTime(at: &origin, layout: layout, metadata: metadata)
        layoutTitle(at: &origin, layout: layout, metadata: metadata)
        layoutDetails(at: &origin, layout: layout, metadata: metadata)
        layoutVotingTitle(at: &origin, layout: layout, metadata: metadata)
        layoutProgressIndicator(at: &origin, layout: layout, metadata: metadata)
        layoutVotingDetails(at: &origin, layout: layout, metadata: metadata)
        layoutTouchAreas(at: &origin, layout: layout, metadata: metadata)
    }

    // MARK: Action

    @IBAction private func actionSupport() {
        guard let viewModel = viewModel else {
            return
        }

        viewModel.delegate?.support(referendum: viewModel)
    }

    @IBAction private func actionUnsupport() {
        guard let viewModel = viewModel else {
            return
        }

        viewModel.delegate?.unsupport(referendum: viewModel)
    }
}

extension ReferendumCollectionViewCell {
    private func layoutImage(at origin: inout CGPoint,
                             layout: ReferendumLayout,
                             metadata: ReferendumLayoutMetadata) {
        imageView.frame = CGRect(origin: origin,
                                 size: layout.imageSize)
        origin.y += layout.imageSize.height
    }

    private func layoutRemainedTime(at origin: inout CGPoint,
                                    layout: ReferendumLayout,
                                    metadata: ReferendumLayoutMetadata) {
        let remainedTitleSize = remainedTitleLabel.intrinsicContentSize
        remainedTitleLabel.frame = CGRect(origin: origin, size: remainedTitleSize)

        let remainedDetailsSize = remainedDetailsLabel.intrinsicContentSize
        let offsetX = remainedTitleLabel.frame.maxX + metadata.remainedHorizontalSpacing
        let width = metadata.drawingBoundingSize.width - remainedTitleSize.width -
            metadata.remainedHorizontalSpacing
        remainedDetailsLabel.frame = CGRect(x: offsetX,
                                            y: origin.y,
                                            width: width,
                                            height: remainedDetailsSize.height)

        origin.y += max(remainedTitleSize.height, remainedDetailsSize.height)
    }

    private func layoutTitle(at origin: inout CGPoint,
                             layout: ReferendumLayout,
                             metadata: ReferendumLayoutMetadata) {
        origin.y += metadata.titleTopSpacing

        let size = CGSize(width: metadata.drawingBoundingSize.width,
                          height: layout.titleSize.height)
        titleLabel.frame = CGRect(origin: origin, size: size)

        origin.y = titleLabel.frame.maxY
    }

    private func layoutDetails(at origin: inout CGPoint,
                               layout: ReferendumLayout,
                               metadata: ReferendumLayoutMetadata) {
        origin.y += metadata.detailsTopSpacing

        let size = CGSize(width: metadata.drawingBoundingSize.width,
                          height: layout.detailsSize.height)
        descriptionLabel.frame = CGRect(origin: origin, size: size)

        origin.y = descriptionLabel.frame.maxY
    }

    private func layoutVotingTitle(at origin: inout CGPoint,
                                   layout: ReferendumLayout,
                                   metadata: ReferendumLayoutMetadata) {
        origin.y += metadata.bottomBarTopSpacing

        let width = metadata.drawingBoundingSize.width
        bottomSeparator.frame = CGRect(origin: origin,
                                       size: CGSize(width: width, height: metadata.bottomSeparatorHeight))

        origin.y = bottomSeparator.frame.maxY + metadata.votingTitleTopSpacing

        let maxWidth = metadata.drawingBoundingSize.width / 2.0

        unsupportTitleLabel.frame = CGRect(origin: origin,
                                           size: CGSize(width: maxWidth, height: metadata.votingTitleHeight))

        let originX = metadata.contentInsets.left + maxWidth
        supportTitleLabel.frame = CGRect(origin: CGPoint(x: originX, y: origin.y),
                                         size: CGSize(width: maxWidth, height: metadata.votingTitleHeight))

        origin.y += metadata.votingTitleHeight
    }

    private func layoutProgressIndicator(at origin: inout CGPoint,
                                         layout: ReferendumLayout,
                                         metadata: ReferendumLayoutMetadata) {
        origin.y += metadata.progressBarTopSpacing

        progressView.transform = .identity

        let size = CGSize(width: metadata.drawingBoundingSize.width, height: metadata.progressBarHeight)
        progressView.frame = CGRect(origin: origin, size: size)

        let separatorSize = progressSeparatorView.frame.size
        progressSeparatorView.frame = CGRect(x: progressView.frame.midX - separatorSize.width / 2.0,
                                             y: progressView.frame.midY - separatorSize.height / 2.0,
                                             width: separatorSize.width,
                                             height: separatorSize.height)

        origin.y = progressView.frame.maxY

        progressView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
    }

    private func layoutVotingDetails(at origin: inout CGPoint,
                                     layout: ReferendumLayout,
                                     metadata: ReferendumLayoutMetadata) {
        origin.y += metadata.votingDetailsTopSpacing

        unsupportVotesImageView.frame = CGRect(origin: origin, size: metadata.votingIndicatorSize)

        let originX = metadata.contentInsets.left + metadata.drawingBoundingSize.width -
            metadata.votingIndicatorSize.width

        supportVotesImageView.frame = CGRect(origin: CGPoint(x: originX, y: origin.y),
                                             size: metadata.votingIndicatorSize)

        let offset = metadata.votingIndicatorSize.width + metadata.votingDetailsHorizontalSpacing
        let width = metadata.drawingBoundingSize.width / 2.0 - offset

        unsupportVotesLabel.frame = CGRect(x: metadata.contentInsets.left + offset,
                                           y: origin.y,
                                           width: width,
                                           height: metadata.votingIndicatorSize.height)

        let supportX = metadata.contentInsets.left + metadata.drawingBoundingSize.width/2.0
        supportVotesLabel.frame = CGRect(x: supportX,
                                         y: origin.y,
                                         width: width,
                                         height: metadata.votingIndicatorSize.height)

        origin.y += metadata.votingIndicatorSize.height
    }

    private func layoutTouchAreas(at origin: inout CGPoint,
                                  layout: ReferendumLayout,
                                  metadata: ReferendumLayoutMetadata) {
        let leftOrigin = CGPoint(x: metadata.touchAreaInset,
                                 y: bottomSeparator.frame.minY + metadata.touchAreaInset)
        let leftSize = CGSize(width: bounds.size.width / 2.0 - 2 * metadata.touchAreaInset,
                              height: bounds.height - bottomSeparator.frame.minY - 2 * metadata.touchAreaInset)
        leftTouchArea.frame = CGRect(origin: leftOrigin, size: leftSize)

        let rightOrigin = CGPoint(x: bounds.size.width / 2.0 + metadata.touchAreaInset,
                                  y: bottomSeparator.frame.minY + metadata.touchAreaInset)
        let rightSize = CGSize(width: bounds.size.width / 2.0 - 2 * metadata.touchAreaInset,
                               height: bounds.height - bottomSeparator.frame.minY - 2 * metadata.touchAreaInset)
        rightTouchArea.frame = CGRect(origin: rightOrigin, size: rightSize)
    }
}

extension ReferendumCollectionViewCell: TimerViewModelDelegate {
    func didStart(_ viewModel: TimerViewModelProtocol) {
        updateRemainedTime()
    }

    func didChangeRemainedTime(_ viewModel: TimerViewModelProtocol) {
        updateRemainedTime()
    }

    func didStop(_ viewModel: TimerViewModelProtocol) {
        updateRemainedTime()

        if viewModel.remainedSeconds <= 0, let mainViewModel = self.viewModel {
            mainViewModel.delegate?.handleElapsedTime(for: mainViewModel)
        }
    }
}
