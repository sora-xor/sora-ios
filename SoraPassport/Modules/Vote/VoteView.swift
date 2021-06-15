import UIKit
import SoraUI

protocol VoteViewDelegate: class {
    func didVote(on view: VoteView, amount: Decimal)
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
        get {
            return sliderView.minimumTrackImage(for: .normal)
        }

        set(newValue) {
            sliderView.setMinimumTrackImage(newValue, for: .normal)
        }
    }

    var maximumTrackImage: UIImage? {
        get {
            return sliderView.maximumTrackImage(for: .normal)
        }

        set(newValue) {
            sliderView.setMaximumTrackImage(newValue, for: .normal)
        }
    }

    var sliderThumb: UIImage? {
        get {
            sliderView.thumbImage(for: .normal)
        }

        set {
            sliderView.setThumbImage(newValue, for: .normal)
        }
    }

    var voteTitle: String? {
        get {
            voteButton.imageWithTitleView?.title
        }

        set {
            voteButton.imageWithTitleView?.title = newValue
        }
    }

    var voteIcon: UIImage? {
        get {
            voteButton.imageWithTitleView?.iconImage
        }

        set {
            voteButton.imageWithTitleView?.iconImage = newValue
        }
    }

    var voteFillColor: UIColor? {
        get {
            voteButton.roundedBackgroundView?.fillColor
        }

        set {
            if let color = newValue {
                voteButton.roundedBackgroundView?.fillColor = color
            }
        }
    }

    var voteHighlightedFillColor: UIColor? {
        get {
            voteButton.roundedBackgroundView?.highlightedFillColor
        }

        set {
            if let color = newValue {
                voteButton.roundedBackgroundView?.highlightedFillColor = color
            }
        }
    }

    var sliderAnimationDuration: TimeInterval = 0.2

    @IBOutlet private var descriptionLabel: UILabel!
    @IBOutlet private var sliderView: UISlider!
    @IBOutlet private var voteTextField: UITextField!
    @IBOutlet private var keyboardActionControl: ActionTitleControl!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var voteButton: RoundedButton!
    @IBOutlet private var cancelButton: RoundedButton!

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

    var value: Decimal? {
        guard let model = model else {
            return nil
        }

        let fraction = Decimal(Double(sliderView.value))
        let min = model.minimumVoteAmount
        let max = model.maximumVoteAmount
        return min + (max - min) * fraction
    }

    weak var delegate: VoteViewDelegate?

    var presenter: ModalInputViewPresenterProtocol?

    // MARK: Initialization

    override func awakeFromNib() {
        super.awakeFromNib()

        setupLocalization()
        adjustLayout()
    }

    override func resignFirstResponder() -> Bool {
        voteTextField.resignFirstResponder()
        return super.resignFirstResponder()
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable
            .projectVoteDialogTitle(preferredLanguages: model?.locale.rLanguages)
        cancelButton.imageWithTitleView?.title = R.string.localizable
            .commonCancel(preferredLanguages: model?.locale.rLanguages)
    }

    private func adjustLayout() {
        leadingConstraint.constant *= designScaleRatio.width
        trallingConstraint.constant *= designScaleRatio.width
        actionsSpacingConstraint.constant *= designScaleRatio.width
        voteWidthConstraint.constant *= designScaleRatio.width
        cancelWidthConstraint.constant *= designScaleRatio.width
        keyboardActionControl.horizontalSpacing *= designScaleRatio.width
    }

    private func setupFromModel() {
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = 1.0

        setupLocalization()
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

            let fraction: Decimal

            let divider = model.maximumVoteAmount - model.minimumVoteAmount

            if divider > 0 {
               fraction = (model.amount - model.minimumVoteAmount) / divider
            } else {
                fraction = 0.0
            }

            let sliderValue = (fraction as NSDecimalNumber).floatValue

            if animated {
                UIView.animate(withDuration: sliderAnimationDuration) {
                    self.sliderView.setValue(sliderValue, animated: animated)
                }
            } else {
                sliderView.setValue(sliderValue, animated: animated)
            }

            updateDescriptionStyle()

            voteButton.isEnabled = model.canVote
        }
    }

    // MARK: Action

    @IBAction private func actionVote(sender: AnyObject) {
        if let amount = value {
            delegate?.didVote(on: self, amount: amount)
        }
    }

    @IBAction private func actionClose(sender: AnyObject) {
        presenter?.hide(view: self, animated: true)
    }

    @IBAction private func sliderDidChange(sender: AnyObject) {
        if let model = model, let amount = value {
            _ = model.updateAmount(with: amount)
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
            let percentage = Decimal(Double(max(min(location.x / sliderWidth, 1.0), 0.0)))
            let amount = model.minimumVoteAmount + percentage * (model.maximumVoteAmount - model.minimumVoteAmount)
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
