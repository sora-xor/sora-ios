import Foundation
import UIKit
import SoraUIKit

final class ExchangeOnboardingSourceViewController: UIViewController {

    private let viewModel: ExchangeOnboardingSourceViewModel

    var rootView: ExchangeOnboardingSourceView {
        view as! ExchangeOnboardingSourceView
    }

    init(viewModel: ExchangeOnboardingSourceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = ExchangeOnboardingSourceView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = R.string.soraCard.onboardingQuestions("3", "3", preferredLanguages: .currentLocale)
        binding()
        updateUI()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    private func binding() {
        rootView.onSource = { [unowned self] source in
            viewModel.handleSource(source)
            updateUI()
        }

        rootView.onContinue = { [unowned self] in
            viewModel.processOnboarding()
        }

        viewModel.onError = { [weak self] errorMessage in
            self?.updateUI(errorMessage: errorMessage)
        }
    }

    private func updateUI(errorMessage: String = "") {
        DispatchQueue.main.async {
            self.rootView.configure(variants: self.viewModel.sources)
            self.rootView.configure(errorMessage: errorMessage)
        }
    }
}
