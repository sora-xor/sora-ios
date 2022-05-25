import UIKit
import SoraUI

public protocol SoraTextDelegate: AnyObject {
    func soraTextFieldShouldReturn(_ textField: NeuTextField) -> Bool
    func soraTextField(_ textField: NeuTextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool
    func soraTextViewDidChange(_ textView: NeuTextView)

    func soraTextView(_ textView: NeuTextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool
}

extension SoraTextDelegate {
    func soraTextFieldShouldReturn(_ textField: NeuTextField) -> Bool { true }

    func soraTextField(_ textField: NeuTextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
        return true
    }
    func soraTextViewDidChange(_ textView: NeuTextView) { }
    func soraTextView(_ textView: NeuTextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
        return true
    }
}

@IBDesignable
open class NeuTextField: UIControl {
    @IBOutlet private var containerView: UIView!
    @IBOutlet private var shadowView: UIView!
    @IBOutlet private var borderView: BorderedContainerView!
    @IBOutlet private var input: UITextField!
    @IBOutlet private var placeholder: UILabel!
    weak var delegate: SoraTextDelegate?

    @IBInspectable var font: UIFont? {
        get {
            input.font
        }
        set {
            input.font = newValue
            placeholder.font = newValue
        }
    }

    @IBInspectable var textColor: UIColor? {
        get {
            input.textColor
        }
        set {
            input.textColor = newValue
        }
    }

    @IBInspectable var placeholderColor: UIColor? {
        get {
            placeholder.textColor
        }
        set {
            placeholder.textColor = newValue
        }
    }

    @IBInspectable var borderColor: UIColor? {
        get {
            borderView.strokeColor
        }
        set {
            borderView.strokeColor = newValue ?? .gray
        }
    }

    @IBInspectable var textAlignment: NSTextAlignment {
        get {
            input.textAlignment
        }
        set {
            input.textAlignment = newValue
            placeholder.textAlignment = newValue
        }
    }

    @IBInspectable var postfixLength: Int = 0

    @IBInspectable var text: String? {
        get {
            input.text
        }
        set {
            var offset: Int = 0
            let oldTextCount = input.text?.count ?? 0
            if oldTextCount > 0 {
                offset = (newValue?.count ?? 0) - oldTextCount
            }
            let range = input.selectedTextRange
            input.text = newValue
            if oldTextCount > 0,
               let range = range,
               let newPosition = input.position(from: range.start, offset: offset) {
                input.selectedTextRange = input.textRange(from: newPosition, to: newPosition)
            }
            placeholder.isHidden = !(newValue?.isEmpty ?? true)
        }
    }

    @IBInspectable var placeholderText: String? {
        get {
            placeholder.text
        }
        set {
            placeholder.text = newValue
        }
    }

    @IBInspectable var returnKeyType: UIReturnKeyType {
        get {
            input.returnKeyType
        }
        set {
            input.returnKeyType = newValue
        }
    }

    @IBInspectable var keyboardType: UIKeyboardType {
        get {
            input.keyboardType
        }
        set {
            input.keyboardType = newValue
        }
    }

    @IBInspectable var textContentType: UITextContentType {
        get {
            input.textContentType
        }
        set {
            input.textContentType = newValue
        }
    }

    @IBInspectable var autocapitalizationType: UITextAutocapitalizationType {
        get {
            input.autocapitalizationType
        }
        set {
            input.autocapitalizationType = newValue
        }
    }

    @IBInspectable var autocorrectionType: UITextAutocorrectionType {
        get {
            input.autocorrectionType
        }
        set {
            input.autocorrectionType = newValue
        }
    }

    @IBInspectable var spellCheckingType: UITextSpellCheckingType {
        get {
            input.spellCheckingType
        }
        set {
            input.spellCheckingType = newValue
        }
    }

    //TODO: discuss with designer if it really necessary
    @IBInspectable var isChangeColorOnEdit: Bool = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        initNib()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initNib()
    }

    func initNib() {
        let bundle = Bundle(for: NeumorphismButton.self)
        bundle.loadNibNamed("NeuTextField", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
//        layoutNeumorphismShadows()
        self.font = UIFont.styled(for: .paragraph2).withSize(29)
        input.delegate = self
        input.addTarget(self, action: #selector(actionEditingChanged), for: .editingChanged)
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()

        return input.becomeFirstResponder()
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()

        return input.resignFirstResponder()
    }

    @objc func actionEditingChanged() {
        placeholder.isHidden = !(input.text ?? "").isEmpty
        sendActions(for: .editingChanged)
    }
}

extension NeuTextField: UITextFieldDelegate {

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        guard isChangeColorOnEdit else { return }
        borderView.isHighlighted = true
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = text, text.isEmpty {
            placeholder.isHidden = false
        }
        guard isChangeColorOnEdit else { return }
        borderView.isHighlighted = false
    }

    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        delegate?.soraTextField(self,
                             shouldChangeCharactersIn: range,
                             replacementString: string)
        ?? true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.soraTextFieldShouldReturn(self) ?? true
    }

    public func textFieldDidChangeSelection(_ textField: UITextField) {
        guard textField == input, postfixLength > 0 else { return }

        // disable postfix selection
        if input.selectedTextRange?.end == input.endOfDocument {
            let correctedPosition = input.position(from: input.endOfDocument, offset: -postfixLength)!
            input.selectedTextRange = input.textRange(from: correctedPosition, to: correctedPosition)
        }
    }
}

@IBDesignable
open class NeuTextView: UIControl {
    @IBOutlet private var containerView: UIView!
    @IBOutlet private var shadowView: UIView!
    @IBOutlet private var borderView: RoundedView!
    @IBOutlet private var input: UITextView!
    @IBOutlet private var placeholder: UILabel!
    weak var delegate: SoraTextDelegate?

    @IBInspectable var font: UIFont? {
        get {
            input.font
        }
        set {
            input.font = newValue
            placeholder.font = newValue
        }
    }

    @IBInspectable var textColor: UIColor? {
        get {
            input.textColor
        }
        set {
            input.textColor = newValue
        }
    }

    @IBInspectable var placeholderColor: UIColor? {
        get {
            placeholder.textColor
        }
        set {
            placeholder.textColor = newValue
        }
    }

    @IBInspectable var borderColor: UIColor? {
        get {
            borderView.strokeColor
        }
        set {
            borderView.strokeColor = newValue ?? .gray
        }
    }

    @IBInspectable var text: String? {
        get {
            input.text
        }
        set {
            input.text = newValue
            placeholder.isHidden = !(newValue?.isEmpty ?? true)
        }
    }

    @IBInspectable var placeholderText: String? {
        get {
            placeholder.text
        }
        set {
            placeholder.text = newValue
        }
    }

    @IBInspectable var returnKeyType: UIReturnKeyType {
        get {
            input.returnKeyType
        }
        set {
            input.returnKeyType = newValue
        }
    }

    @IBInspectable var keyboardType: UIKeyboardType {
        get {
            input.keyboardType
        }
        set {
            input.keyboardType = newValue
        }
    }

    @IBInspectable var textContentType: UITextContentType {
        get {
            input.textContentType
        }
        set {
            input.textContentType = newValue
        }
    }

    @IBInspectable var autocapitalizationType: UITextAutocapitalizationType {
        get {
            input.autocapitalizationType
        }
        set {
            input.autocapitalizationType = newValue
        }
    }

    @IBInspectable var autocorrectionType: UITextAutocorrectionType {
        get {
            input.autocorrectionType
        }
        set {
            input.autocorrectionType = newValue
        }
    }

    @IBInspectable var spellCheckingType: UITextSpellCheckingType {
        get {
            input.spellCheckingType
        }
        set {
            input.spellCheckingType = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initNib()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initNib()
    }

    func initNib() {
        let bundle = Bundle(for: NeumorphismButton.self)
        bundle.loadNibNamed("NeuTextView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
//        layoutNeumorphismShadows()
        input.text = nil
        self.font = UIFont.styled(for: .paragraph2).withSize(15)
        input.delegate = self

    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()

        return input.becomeFirstResponder()
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()

        return input.resignFirstResponder()
    }

    @objc func actionEditingChanged() {
        placeholder.isHidden = !(input.text ?? "").isEmpty
        sendActions(for: .editingChanged)
    }
}

extension NeuTextView: UITextViewDelegate {
    public func textViewDidEndEditing(_ textView: UITextView) {
        borderView.isHighlighted = false
    }
    public func textViewDidBeginEditing(_ textView: UITextView) {
        borderView.isHighlighted = true
    }
    public func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !(input.text ?? "").isEmpty
        sendActions(for: .editingChanged)
        delegate?.soraTextViewDidChange(self)
    }
    public func textView(_ textView: UITextView,
                         shouldChangeTextIn range: NSRange,
                         replacementText text: String) -> Bool {
        return delegate?.soraTextView(self, shouldChangeTextIn: range, replacementText: text) ?? true
    }

}
