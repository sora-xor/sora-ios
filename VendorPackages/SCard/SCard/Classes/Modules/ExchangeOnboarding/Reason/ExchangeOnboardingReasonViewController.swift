import Foundation
import UIKit
import SoraUIKit

final class ExchangeOnboardingReasonViewController: UIViewController {

    private let viewModel: ExchangeOnboardingReasonViewModel

    var rootView: ExchangeOnboardingReasonView {
        view as! ExchangeOnboardingReasonView
    }

    init(viewModel: ExchangeOnboardingReasonViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = ExchangeOnboardingReasonView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = R.string.soraCard.onboardingQuestions("2", "3", preferredLanguages: .currentLocale)
        binding()
        updateUI()
    }

    private func binding() {
        rootView.onReason = { [unowned self] reason in
            viewModel.handleReason(reason)
            updateUI()
        }

        rootView.onContinue = { [unowned self] in
            viewModel.next()
        }
    }

    private func updateUI() {
        rootView.configure(variants: viewModel.reasons)
    }
}
