import Foundation
import UIKit
import SoraUIKit

final class KYCNotRegistredController: UIViewController {

    var onTryAnotherNumber: (() -> Void)?
    var onRegister: (() -> Void)?

    private let data: KYCUserDataModel

    private var rootView: KYCNotRegistredView {
        view as! KYCNotRegistredView
    }

    init(data: KYCUserDataModel) {
        self.data = data
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        view = KYCNotRegistredView()
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
        self.navigationItem.rightBarButtonItem?.tintColor = SoramitsuUI.shared.theme.palette.color(.fgPrimary)
        rootView.configure(phoneNumber: data.fullPhoneNumber)
        binding()
    }

    private func binding() {

        rootView.onTryAnotherNumberButton = { [unowned self] in
            onTryAnotherNumber?()
        }

        rootView.onRegisterButton = { [unowned self] in
            data.loginCase = .register
            data.phoneNumber = ""
            onRegister?()
        }
    }

    @objc func onCloseButton() {
        // TODO: close
        dismiss(animated: true)
    }
}
