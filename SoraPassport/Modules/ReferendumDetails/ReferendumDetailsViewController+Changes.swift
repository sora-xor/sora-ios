import UIKit

extension ReferendumDetailsViewController {
    func updateMainImage(_ referendum: ReferendumDetailsViewModelProtocol) {
        viewModel?.mainImageViewModel?.cancel()
        imageView.image = nil

        if let image = referendum.mainImageViewModel?.image {
            imageView.image = image
            return
        }

        referendum.mainImageViewModel?.loadImage { [weak self] (image, error) in
            guard error == nil else {
                return
            }

            guard let strongSelf = self else {
                return
            }

            strongSelf.imageView.image = image
            strongSelf.imageAppearanceAnimator.animate(view: strongSelf.imageView, completionBlock: nil)
        }
    }

    func updateRemainedTime(_ referendum: ReferendumDetailsViewModelProtocol) {
        let locale = localizationManager?.selectedLocale

        if let remainedTime = referendum.remainedTimeViewModel?.remainedSeconds {
            if remainedTime > 0.0 {
                remainedTitleLabel.text = R.string.localizable
                    .referendumEndsInTitle(preferredLanguages: locale?.rLanguages)
                remainedDetailsLabel.text = referendum.remainedTimeViewModel?.titleForLocale(locale)
            } else {
                remainedTitleLabel.text = referendum.remainedTimeViewModel?.titleForLocale(locale)
                remainedDetailsLabel.text = ""
            }
        } else {
            remainedTitleLabel.text = R.string.localizable
                .referendumEndedTitle(preferredLanguages: locale?.rLanguages)
            remainedDetailsLabel.text = referendum.content.remainedTimeDetails
        }
    }

    func updateVotingResult(_ referendum: ReferendumDetailsViewModelProtocol) {
        supportVoteButton.isHidden = referendum.content.finished
        unsupportVoteButton.isHidden = referendum.content.finished

        leftTouchArea.isUserInteractionEnabled = !referendum.content.finished
        rightTouchArea.isUserInteractionEnabled = !referendum.content.finished

        openStateBottom.isActive = !referendum.content.finished
        finishedStateBottom.isActive = referendum.content.finished

        resultTitleLabel.isHidden = !referendum.content.finished
        resultDetailsLabel.isHidden = !referendum.content.finished
        resultIcon.isHidden = !referendum.content.finished

        votingResultEnabled.isActive = referendum.content.finished
        votingResultDisabled.isActive = !referendum.content.finished

        let languages = localizationManager?.preferredLocalizations

        switch referendum.content.status {
        case .accepted:
            resultIcon.image = R.image.iconThumbUp()
            resultIcon.tintColor = UIColor.darkRed
            resultDetailsLabel.text = R.string.localizable
                .referendumSupportTitle(preferredLanguages: languages)
            resultDetailsLabel.textColor = UIColor.darkRed
        case .rejected:
            resultIcon.image = R.image.iconThumbDown()
            resultIcon.tintColor = UIColor.silver
            resultDetailsLabel.text = R.string.localizable
                .referendumUnsupportTitle(preferredLanguages: languages)
            resultDetailsLabel.textColor = UIColor.silver
        case .open:
            break
        }
    }

    func updateTextDetails(_ referendum: ReferendumDetailsViewModelProtocol) {
        titleLabel.text = referendum.content.title
        detailsTextView.text = referendum.content.details
    }

    func updateTotalVotes(_ referendum: ReferendumDetailsViewModelProtocol) {
        let languages = localizationManager?.preferredLocalizations

        if let totalVotes = referendum.content.totalVotes {
            totalTitleLabel.text = R.string.localizable
                .referendumTotalVotes(preferredLanguages: languages)
            totalDetailsLabel.text = totalVotes
        } else {
            totalTitleLabel.text = R.string.localizable
                .referendumNoVotes(preferredLanguages: languages)
            totalDetailsLabel.text = ""
        }
    }

    func updateCommonVotes(_ referendum: ReferendumDetailsViewModelProtocol) {
        supportVotesLabel.text = referendum.content.supportingVotes
        unsupportVotesLabel.text = referendum.content.unsupportingVotes

        progressView.setProgress(CGFloat(referendum.content.votingProgress), animated: false)
    }

    func updateMyVotes(_ referendum: ReferendumDetailsViewModelProtocol) {
        mySupportVotesLabel.text = referendum.content.mySupportingVotes
        myUnsupportVotesLabel.text = referendum.content.myUnsupportingVotes
    }
}
