import Foundation
import UIKit
import SoraUIKit

final class EmploymentStatusViewController: UIViewController {

    private let viewModel: EmploymentStatusViewModel

    var rootView: EmploymentStatusView {
        view as! EmploymentStatusView
    }

    init(viewModel: EmploymentStatusViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = EmploymentStatusView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = R.string.soraCard.onboardingQuestions("1", "2", preferredLanguages: .currentLocale)
        binding()
        configure()
    }

    private func binding() {
        rootView.onEmploymentStatus = { [unowned self] employmentStatus in
            viewModel.employmentStatus = employmentStatus
            rootView.select(variant: employmentStatus)
        }

        rootView.onContinue = { [unowned self] in
            viewModel.next()
        }
    }

    private func configure() {
        let variants = ExchangeOnboarding.EmploymentStatus.allCases
        rootView.configure(variants: variants, selected: viewModel.employmentStatus)
    }
}
