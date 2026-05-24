import Foundation
import UIKit
import SoraUIKit

final class KYCEnterEmailCodeViewController: UIViewController {

    private let viewModel: KYCEnterEmailCodeViewModel

    var rootView: KYCEnterEmailCodeView {
        view as! KYCEnterEmailCodeView
    }

    init(viewModel: KYCEnterEmailCodeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = KYCEnterEmailCodeView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = R.string.soraCard.verifyEmailTitle(preferredLanguages: .currentLocale)
        binding()
        configure()

        viewModel.checkEmail()
    }

    private func binding() {
        rootView.onResendButton = { [unowned self] in
            viewModel.resendVerificationLink()
            configure()
        }

        rootView.onChangeEmailButton = { [unowned self] in
            viewModel.onChangeEmail?()
        }
    }

    private func configure() {
        let secondsLeft = abs(Int(Date().timeIntervalSince(viewModel.data.lastEmailOTPSentDate + 60)))
        rootView.configure(
            email: viewModel.data.email,
            secondsLeft: secondsLeft
        )
    }
}
