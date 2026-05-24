import Foundation
import UIKit
import SoraUIKit

final class ExchangeOnboardingVolumeViewController: UIViewController {

    private let viewModel: ExchangeOnboardingVolumeViewModel

    var rootView: ExchangeOnboardingVolumeView {
        view as! ExchangeOnboardingVolumeView
    }

    init(viewModel: ExchangeOnboardingVolumeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = ExchangeOnboardingVolumeView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = R.string.soraCard.onboardingQuestions("1", "2", preferredLanguages: .currentLocale)
        binding()
        configure()
    }

    private func binding() {
        rootView.onVolume = { [unowned self] volume in
            viewModel.volume = volume
            rootView.select(variant: volume)
        }

        rootView.onContinue = { [unowned self] in
            viewModel.next()
        }
    }

    private func configure() {
        let variants = ExchangeOnboarding.ExpectedVolume.allCases
        rootView.configure(variants: variants, selected: viewModel.volume)
    }
}
