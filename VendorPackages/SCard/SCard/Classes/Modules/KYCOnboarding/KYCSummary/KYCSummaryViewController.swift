import Foundation
import UIKit
import SoraUIKit

final class KYCSummaryViewController: UIViewController {

    private let viewModel: KYCSummaryViewModel

    private var rootView: KYCSummaryView {
        view as! KYCSummaryView
    }

    init(viewModel: KYCSummaryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = KYCSummaryView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        binding()
        Task { await viewModel.getKYCAttempts() }
    }

    private func configure() {
        self.navigationItem.title = R.string.soraCard.getPreparedTitle(preferredLanguages: .currentLocale)
        self.navigationItem.setHidesBackButton(true, animated: false)

        let logoutButton = UIBarButtonItem(
            title: R.string.soraCard.logOut(preferredLanguages: .currentLocale),
            style: .plain,
            target: self,
            action: #selector(onLogout)
        )
        logoutButton.setTitleTextAttributes(
            [
                .foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary),
                .font: FontType.textBoldS.font
            ],
            for: .normal
        )
        self.navigationItem.leftBarButtonItem = logoutButton

        self.navigationItem.rightBarButtonItem = .init(
            image: R.image.close(),
            style: .done,
            target: self,
            action: #selector(onClose)
        )
    }

    private func binding() {
        rootView.onContinueButton = { [weak viewModel] in
            viewModel?.onContinue?()
        }

        viewModel.onAttempts = { [unowned self] attempts, retryFee in
            DispatchQueue.main.async {
                self.rootView.configure(attempts: Int(attempts), retryFee: retryFee)
            }
        }
    }

    @objc func onClose() {
        viewModel.onClose?()
    }

    @objc func onLogout() {
        viewModel.onLogout?()
    }
}
