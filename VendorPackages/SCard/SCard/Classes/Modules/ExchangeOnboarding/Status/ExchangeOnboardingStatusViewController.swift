import Foundation
import UIKit
import SoraUIKit

final class ExchangeOnboardingStatusViewController: UIViewController {

    private let viewModel: ExchangeOnboardingStatusViewModel

    var rootView: ExchangeOnboardingStatusView {
        view as! ExchangeOnboardingStatusView
    }

    init(viewModel: ExchangeOnboardingStatusViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = ExchangeOnboardingStatusView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = R.string.soraCard.commonOnboarding(preferredLanguages: .currentLocale)
        binding()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    private func binding() {
        rootView.onSupportButton = { [unowned self] in
            viewModel.onSupport?()
        }

        viewModel.onClose = { [unowned self] in
            viewModel.onClose?()
        }

        viewModel.onUpdateUI = { [unowned self] data in
            DispatchQueue.main.async { [weak self] in
                self?.rootView.configure(data: data)
            }
        }
    }
}
