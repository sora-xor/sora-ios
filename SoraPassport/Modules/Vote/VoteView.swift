/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

protocol VoteViewDelegate: class {
    func didVote(on view: VoteView, amount: Float)
    func didCancel(on view: VoteView)
}

class VoteView: UIView, AdaptiveDesignable, ModalInputViewProtocol {

    var normalDescriptionColor: UIColor = .gray {
        didSet {
            updateDescriptionStyle()
        }
    }

    var errorDescriptionColor: UIColor = .red {
        didSet {
            updateDescriptionStyle()
        }
    }

    var minimumTrackImage: UIImage? {
        set(newValue) {
            sliderView.setMinimumTrackImage(newValue, for: .normal)
        }

        get {
            return sliderView.minimumTrackImage(for: .normal)
        }
    }

    var maximumTrackImage: UIImage? {
        set(newValue) {
            sliderView.setMaximumTrackImage(newValue, for: .normal)
        }

        get {
            return sliderView.maximumTrackImage(for: .normal)
        }
    }

    var sliderAnimationDuration: TimeInterval = 0.2

    @IBOutlet private var descriptionLabel: UILabel!
    @IBOutlet private var sliderView: UISlider!
    @IBOutlet private var voteTextField: UITextField!
    @IBOutlet private var keyboardActionControl: ActionTitleControl!
    @IBOutlet private var voteButton: RoundedButton!

    @IBOutlet private var leadingConstraint: NSLayoutConstraint!
    @IBOutlet private var trallingConstraint: NSLayoutConstraint!
    @IBOutlet private var actionsSpacingConstraint: NSLayoutConstraint!
    @IBOutlet private var voteWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var cancelWidthConstraint: NSLayoutConstraint!

    var model: VoteViewModelProtocol? {
        didSet {
            setupFromModel()
        }
    }

    weak var delegate: VoteViewDelegate?

    var presenter: ModalInputViewPresenterProtocol?

    // MARK: Initialization

    override func awakeFromNib() {
        super.awakeFromNib()

        configure()
        adjustLayout()
    }

    override func resignFirstResponder() -> Bool {
        voteTextField.resignFirstResponder()
        return super.resignFirstResponder()
    }

    private func adjustLayout() {
        leadingConstraint.constant *= designScaleRatio.width
        trallingConstraint.constant *= designScaleRatio.width
        actionsSpacingConstraint.constant *= designScaleRatio.width
        voteWidthConstraint.constant *= designScaleRatio.width
        cancelWidthConstraint.constant *= designScaleRatio.width
        keyboardActionControl.horizontalSpacing *= designScaleRatio.width
    }

    private func configure() {
        sliderView.setMinimumTrackImage(minimumTrackImage, for: .normal)
        sliderView.setMaximumTrackImage(maximumTrackImage, for: .normal)
    }

    private func setupFromModel() {
        guard let model = model else {
            return
        }

        sliderView.minimumValue = model.minimumVoteAmount
        sliderView.maximumValue = model.maximumVoteAmount

        updateDisplay(animated: false)
    }

    private func updateDescriptionStyle() {
        if let model = model {
            descriptionLabel.textColor = model.canVote ? normalDescriptionColor : errorDescriptionColor
        }
    }

    private func updateDisplay(animated: Bool) {
        if let model = model {
            descriptionLabel.text = model.description
            voteTextField.text = model.formattedAmount

            if animated {
                UIView.animate(withDuration: sliderAnimationDuration) {
                    self.sliderView.setValue(model.amount, animated: animated)
                }
            } else {
                sliderView.setValue(model.amount, animated: animated)
            }

            updateDescriptionStyle()

            if model.canVote {
                voteButton.enable()
            } else {
                voteButton.disable()
            }
        }
    }

    // MARK: Action

    @IBAction private func actionVote(sender: AnyObject) {
        delegate?.didVote(on: self, amount: sliderView.value)
    }

    @IBAction private func actionClose(sender: AnyObject) {
        presenter?.hide(view: self, animated: true)
    }

    @IBAction private func sliderDidChange(sender: AnyObject) {
        if let model = model {
            _ = model.updateAmount(with: Float(round(sliderView.value)))
            updateDisplay(animated: false)
        }
    }

    @IBAction private func sliderTouchUpInside(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else {
            return
        }

        let location = gestureRecognizer.location(in: sliderView)
        let sliderWidth = sliderView.bounds.width

        if let model = model, sliderWidth > 0.0 {
            let percentage = Float(min(location.x / sliderWidth, 1.0))
            let amount = percentage * model.maximumVoteAmount
            model.updateAmount(with: amount)
            updateDisplay(animated: true)
        }
    }

    @IBAction private func keyboardControlDidChange(sender: AnyObject) {
        if keyboardActionControl.isActivated {
            voteTextField.becomeFirstResponder()
        } else {
            voteTextField.resignFirstResponder()
        }
    }

    @IBAction private func textFieldDidChange(sender: AnyObject) {
        if let model = model, let text = voteTextField.text {
            _ = model.updateAmount(with: text)

            updateDisplay(animated: true)
        }
    }
}

extension VoteView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        keyboardActionControl.activate(animated: true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        keyboardActionControl.deactivate(animated: true)
    }
}
