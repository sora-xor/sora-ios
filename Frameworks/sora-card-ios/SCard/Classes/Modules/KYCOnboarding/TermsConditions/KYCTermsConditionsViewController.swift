import Foundation
import UIKit
import SoraUIKit

final class KYCTermsConditionsViewController: UIViewController {

    private let viewModel: KYCTermsConditionsViewModel

    private var rootView: KYCTermsConditionsView {
        view as! KYCTermsConditionsView
    }

    init(viewModel: KYCTermsConditionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = KYCTermsConditionsView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        binding()
    }

    private func binding() {
        rootView.onBlacklistedCountriesButton = { [unowned viewModel] in
            viewModel.onBlacklistedCountries?()
        }
        rootView.termsConditionsButtons.onGeneralTerms = { [unowned viewModel] in
            viewModel.onGeneralTerms?()
        }
        rootView.termsConditionsButtons.onPrivacy = { [unowned viewModel] in
            viewModel.onPrivacy?()
        }
        rootView.onAcceptButton = { [unowned viewModel] in
            viewModel.onAccept?()
        }
    }
}
