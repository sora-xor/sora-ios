import Foundation
import UIKit
import SoraUIKit

final class LoginViewController: UIViewController {

    var onLogin: (() -> Void)?
    var onUnsupportedCountries: (() -> Void)?

    private let data: KYCUserDataModel

    private var rootView: LoginView {
        view as! LoginView
    }

    init(data: KYCUserDataModel) {
        self.data = data
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        view = LoginView()
        title = R.string.soraCard.statusNotStarted(preferredLanguages: .currentLocale)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        binding()
    }

    private func binding() {

        rootView.onRegister = { [unowned self] in
            data.loginCase = .register
            self.onLogin?()
        }

        rootView.onLogin = { [unowned self] in
            data.loginCase = .login
            self.onLogin?()
        }

        rootView.onUnsupportedCountries = { [unowned self] in
            self.onUnsupportedCountries?()
        }
    }
}
