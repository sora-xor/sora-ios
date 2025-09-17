import UIKit
import SoraUI

final class AnimatedTextViewController: UIViewController {
    @IBOutlet private var name1Field: AnimatedTextField!
    @IBOutlet private var name2Field: AnimatedTextField!

    @IBAction private func actionName1Change() {
        name2Field.text = name1Field.text
    }

    @IBAction private func actionName2Change() {
        name1Field.text = name2Field.text
    }

    @IBAction private func actionDone() {
        name1Field.resignFirstResponder()
        name2Field.resignFirstResponder()
    }
}
