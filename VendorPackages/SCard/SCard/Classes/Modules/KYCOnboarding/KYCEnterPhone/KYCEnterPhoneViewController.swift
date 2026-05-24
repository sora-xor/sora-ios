import Foundation
import UIKit
import SoraUIKit

final class KYCEnterPhoneViewController: UIViewController {

    private let viewModel: KYCEnterPhoneViewModel

    private var rootView: KYCEnterPhoneView {
        view as! KYCEnterPhoneView
    }

    init(viewModel: KYCEnterPhoneViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = KYCEnterPhoneView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = R.string.soraCard.verifyPhoneNumberTitle(preferredLanguages: .currentLocale)
        binding()
        viewModel.setupCrrentCountry()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rootView.inputField.textField.becomeFirstResponder()
        rootView.inputField.textField.sora.text = viewModel.data.phoneNumber
    }

    private func binding() {

        rootView.onCountry = { [unowned viewModel] in
            viewModel.onCountry?()
        }

        rootView.onContinueButton = { [unowned viewModel] in
            viewModel.signIn()
        }

        rootView.onInput = { [unowned viewModel] text in
            viewModel.onInput(text: text)
        }

        viewModel.onUpdateUI = { [unowned self] errorMessage, isContinueEnabled, secondsLeft in
            DispatchQueue.main.async { [unowned self] in
                rootView.configure(
                    errorMessage: errorMessage,
                    isContinueEnabled: isContinueEnabled,
                    secondsLeft: secondsLeft
                )
            }
        }

        viewModel.onPhoneNumber = { [unowned self] phoneNumber in
            rootView.configure(phoneNumber: phoneNumber)
        }

        viewModel.onUpdateCountry = { [unowned self] country in
            DispatchQueue.main.async { [unowned self] in
                rootView.configure(country: country)
            }
        }
    }
}
