import UIKit

public enum InputFieldState {
    case `default`
    case focused
    case success
    case fail
    case disabled

    var isResultState: Bool {
        return self == .success || self == .fail
    }

    var descriptionColor: SoramitsuColor {
        switch self {
        case .`default`, .focused: return .fgSecondary
        case .success: return .statusSuccess
        case .fail: return .statusError
        case .disabled: return .fgTertiary
        }
    }
}

public final class InputFieldConfiguration<Type: InputField>: SoramitsuViewConfiguration<Type> {
    private var isResettingValidation = false

    public var state: InputFieldState = .default {
        didSet(oldState) {
            if !isResettingValidation && oldState.isResultState && (state == .focused || state == .default) {
                state = oldState
            }
            updateView()
        }
    }

    /// A validation result belongs to the value that was checked. Call this
    /// when editing replaces that value; focus changes alone keep the result.
    public func resetValidation() {
        isResettingValidation = true
        descriptionLabelText = nil
        state = owner?.textField.isFirstResponder == true ? .focused : .default
        isResettingValidation = false
    }

    public var leftImage: UIImage? {
        didSet {
            owner?.leftImageView.image = leftImage
            owner?.leftImageView.isHidden = leftImage == nil
        }
    }

    public var text: String? {
        set {
            owner?.textField.sora.text = newValue
            owner?.titleLabel.sora.isHidden = text?.isEmpty ?? true
        }
        get {
            owner?.textField.sora.text
        }
    }

    public var titleLabelText: String? {
        didSet {
            owner?.titleLabel.sora.text = titleLabelText
            owner?.titleLabel.sora.isHidden = owner?.textField.text?.isEmpty ?? true
        }
    }

    public var textFieldPlaceholder: String = "" {
        didSet {
            owner?.textField.sora.placeholder = textFieldPlaceholder
        }
    }

    public var buttonImage: UIImage? {
        didSet {
            owner?.button.sora.image = buttonImage
            owner?.button.sora.isHidden = buttonImage == nil
        }
    }
    
    public var buttonImageTintColor: SoramitsuColor? {
        didSet {
            owner?.button.sora.tintColor = buttonImageTintColor ?? .fgSecondary
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
            owner?.textField.keyboardType = keyboardType
        }
    }

    public var textContentType: UITextContentType = .name {
        didSet {
            owner?.textField.textContentType = textContentType
        }
    }

    public func addHandler(for event: SoramitsuControlConfiguration<SoramitsuTextField>.Event, handler: (() -> Void)?) {
        owner?.textField.sora.addHandler(for: event, position: .last, handler: handler)
    }

    public func addHandler(for events: SoramitsuControlConfiguration<SoramitsuTextField>.Event..., handler: (() -> Void)?) {
        guard let handler = handler else { return }
        for event in events {
            owner?.textField.sora.addHandler(for: event, handler: handler)
        }
    }

    private var textObservation: NSKeyValueObservation?

    init(style: SoramitsuStyle, state: InputFieldState) {
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

    /// Fill, border and focus glow (spec §7.5). A password field gets the
    /// focused border only: secrets never glow (spec §1.8).
    private func applyInputChrome() {
        guard let owner else { return }
        NeonInputStyle.apply(to: owner.stackView, state: state, isEnabled: isEnabled, cornerRadius: 16,
                             focusGlow: !owner.textField.isSecureTextEntry)
    }
}
