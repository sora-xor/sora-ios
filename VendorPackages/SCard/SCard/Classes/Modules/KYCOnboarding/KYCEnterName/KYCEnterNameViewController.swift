import Foundation
import UIKit
import SoraUIKit

final class KYCEnterNameViewController: UIViewController {

    private let viewModel: KYCEnterNameViewModel

    var rootView: KYCEnterNameView {
        view as! KYCEnterNameView
    }

    init(viewModel: KYCEnterNameViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = KYCEnterNameView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title =  R.string.soraCard.userRegistrationTitle(preferredLanguages: .currentLocale)
        binding()
        configure()
    }

    private func binding() {
        rootView.onName = { [unowned self] name in
            viewModel.data.name = name
            configure()
        }

        rootView.onLastname = { [unowned self] lastname in
            viewModel.data.lastname = lastname
            configure()
        }

        rootView.onContinue = { [unowned self] in
            viewModel.onContinue?(viewModel.data)
        }
    }

    private func configure() {
        rootView.configure(isContinueButtonEnabled: viewModel.isContinueEnabled)
    }
}
