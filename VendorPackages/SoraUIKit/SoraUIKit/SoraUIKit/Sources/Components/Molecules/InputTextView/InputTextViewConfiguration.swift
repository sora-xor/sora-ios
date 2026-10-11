import UIKit

public enum InputTextViewState {
    case `default`
    case focused
    case success
    case fail
    case disabled

    var isResultState: Bool {
        return self == .success || self == .fail
    }

    var fieldState: InputFieldState {
        switch self {
        case .`default`: return .default
        case .focused: return .focused
        case .success: return .success
        case .fail: return .fail
        case .disabled: return .disabled
        }
    }

    var descriptionColor: SoramitsuColor {
        fieldState.descriptionColor
    }
}

public final class InputTextViewConfiguration<Type: InputTextView>: SoramitsuViewConfiguration<Type> {
    public var state: InputTextViewState = .default {
        didSet(oldState) {
            if (oldState.isResultState && state == .focused) || (oldState.isResultState && state == .default) {
                state = oldState
            }
            updateView()
        }
    }

    public var text: String? {
        set {
            owner?.textView.sora.text = newValue
        }
        get {
            owner?.textView.sora.text
        }
    }

    public var descriptionLabelText: String? {
        didSet {
            owner?.descriptionLabel.sora.text = descriptionLabelText
            owner?.descriptionLabel.sora.isHidden = descriptionLabelText == nil
        }
    }

    public var isEnabled: Bool = true {
        didSet {
            owner?.isUserInteractionEnabled = isEnabled
            state = isEnabled ? .default : .disabled
        }
    }

    public var keyboardType: UIKeyboardType = .default {
        didSet {
            owner?.textView.keyboardType = keyboardType
        }
    }

    public var textContentType: UITextContentType = .name {
        didSet {
            owner?.textView.textContentType = textContentType
        }
    }

    private var textObservation: NSKeyValueObservation?

    init(style: SoramitsuStyle, state: InputTextViewState) {
        self.state = state
        super.init(style: style)
        updateView()
    }

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            updateView()
        } else if options.contains(.effects) {
            applyInputChrome()
        }
    }

    func updateView() {
        guard let owner else { return }
        applyInputChrome()
        owner.descriptionLabel.sora.textColor = state.descriptionColor
    }

    /// Fill and border (spec §7.5). No focus glow: this is the field the
    /// recovery phrase or seed is typed into, and secrets never glow
    /// (spec §1.8).
    private func applyInputChrome() {
        guard let owner else { return }
        NeonInputStyle.apply(to: owner.stackView, state: state.fieldState, isEnabled: isEnabled, cornerRadius: 16,
                             focusGlow: false)
    }
}
