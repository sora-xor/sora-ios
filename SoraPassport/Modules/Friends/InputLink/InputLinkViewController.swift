/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraFoundation
import Anchorage

protocol InputLinkViewInput: AnyObject {
    func changeButton(to state: InputLinkActivateButtonState)
    func dismiss(with completion: @escaping () -> Void)
}

protocol InputLinkViewOutput: InputLinkViewDelegate {

}

final class InputLinkViewController: UIViewController {

    var presenter: InputLinkViewOutput

    lazy var inputLinkView: InputLinkView = {
        let view = InputLinkView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.localizationManager = LocalizationManager.shared
        view.delegate = presenter
        return view
    }()

    private var dragIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.layer.cornerRadius = 2
        return view
    }()

    private var heightConstraint: NSLayoutConstraint?

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    init(presenter: InputLinkViewOutput) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            let keyboardHeight = keyboardRectangle.height

            UIView.animate(withDuration: 0.5) {
                self.heightConstraint?.constant = keyboardHeight + 307
                self.view.setNeedsLayout()
            }
        }
    }
}

extension InputLinkViewController: InputLinkViewInput {
    func changeButton(to state: InputLinkActivateButtonState) {
        inputLinkView.activateButton.isEnabled = state.isEnabled
        inputLinkView.activateButton.color = state.backgroundColor
        inputLinkView.activateButton.setTitleColor(state.textColor, for: .normal)
    }

    func dismiss(with completion: @escaping () -> Void) {
        dismiss(animated: true, completion: completion)
    }
}

// MARK: - Private Functions

private extension InputLinkViewController {

    func configure() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        view.addSubview(inputLinkView)
        view.addSubview(dragIndicatorView)

        heightConstraint = inputLinkView.heightAnchor.constraint(equalToConstant: 307)
        heightConstraint?.isActive = true

        dragIndicatorView.do {
            $0.topAnchor == inputLinkView.topAnchor + 4
            $0.centerXAnchor == view.centerXAnchor
            $0.heightAnchor == 4
            $0.widthAnchor == 64
        }

        inputLinkView.do {
            $0.bottomAnchor == view.bottomAnchor
            $0.centerXAnchor == view.centerXAnchor
            $0.leadingAnchor == view.leadingAnchor
        }

        inputLinkView.textField.becomeFirstResponder()
    }
}
