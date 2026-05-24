import Foundation
import UIKit
import SoraUIKit

final class KYCStatusViewController: UIViewController {

    private let viewModel: KYCStatusViewModel

    private var rootView: KYCStatusView {
        view as! KYCStatusView
    }

    init(viewModel: KYCStatusViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = KYCStatusView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.setHidesBackButton(true, animated: false)
        self.navigationItem.rightBarButtonItem = .init(
            image: R.image.close(),
            style: .done,
            target: self,
            action: #selector(onCloseButton)
        )
        binding()

        Task {
            await viewModel.getKYCStatus()
        }
    }

    private func binding() {

        rootView.onRetryButton = { [unowned viewModel] in
            DispatchQueue.main.async {
                viewModel.onRetry?()
            }
        }

        rootView.onLogoutButton = { [unowned viewModel] in
            DispatchQueue.main.async {
                viewModel.onLogout?()
            }
        }

        rootView.onSupportButton = { [unowned viewModel] in
            DispatchQueue.main.async {
                viewModel.onSupport?()
            }
        }

        viewModel.onError = { [unowned rootView] error in
            DispatchQueue.main.async {
                rootView.configure(error: error)
            }
        }

        viewModel.onStatus = { [unowned rootView] status, freeAttemptsLeft, retryFee in
            DispatchQueue.main.async {
                rootView.configure(state: status, freeAttemptsLeft: freeAttemptsLeft, retryFee: retryFee)
            }
        }
    }

    @objc func onCloseButton() {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.onClose?()
        }
    }
}
