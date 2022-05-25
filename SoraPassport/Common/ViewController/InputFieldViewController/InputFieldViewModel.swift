import Foundation

protocol InputFieldViewModelDelegate: class {
    func inputFieldDidCompleteInput(to viewModel: InputFieldViewModelProtocol)
    func inputFieldDidCancelInput(to viewModel: InputFieldViewModelProtocol)
}

protocol InputFieldViewModelProtocol {
    var title: String { get }
    var hint: String { get }
    var cancelActionTitle: String { get }
    var doneActionTitle: String { get }

    var value: String { get }

    var isComplete: Bool { get }

    var delegate: InputFieldViewModelDelegate? { get }

    func didReceive(replacement: String, in range: NSRange) -> Bool
}

class InputFieldViewModel: InputFieldViewModelProtocol {
    let title: String
    let hint: String
    let cancelActionTitle: String
    let doneActionTitle: String

    weak var delegate: InputFieldViewModelDelegate?

    var completionPredicate: NSPredicate?
    var invalidCharacters: CharacterSet?
    var maximumLength: Int = 0

    var isComplete: Bool {
        if let predicate = completionPredicate {
            return predicate.evaluate(with: value)
        } else {
            return true
        }
    }

    private(set) var value: String = ""

    init(title: String, hint: String, cancelActionTitle: String, doneActionTitle: String) {
        self.title = title
        self.hint = hint
        self.cancelActionTitle = cancelActionTitle
        self.doneActionTitle = doneActionTitle
    }

    func didReceive(replacement: String, in range: NSRange) -> Bool {
        let newValue = (value as NSString).replacingCharacters(in: range, with: replacement)

        if maximumLength > 0, newValue.count > maximumLength {
            return false
        }

        if let invalidCharacters = invalidCharacters, newValue.rangeOfCharacter(from: invalidCharacters) != nil {
            return false
        }

        value = newValue

        return true
    }
}
