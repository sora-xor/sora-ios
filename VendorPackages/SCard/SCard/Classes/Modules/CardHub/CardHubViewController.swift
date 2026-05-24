import Foundation
import UIKit
import SoraUIKit

final class CardHubViewController: UIViewController {

    var onExhange: (() -> Void)?
    var onManaageAppStore: (() -> Void)?
    var onLogout: (() -> Void)?
    var onSupport: (() -> Void)?
    var onUpdateApp: (() -> Void)?

    private let model: CardHubViewModel

    private var rootView: CardHubView {
        view as! CardHubView
    }

    init(model: CardHubViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = CardHubView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        binding()
        model.fetchPhoneNumber()
        model.fetchIban()
    }

    private func binding() {

        model.onUpdateUI = { [weak self] iban, needUpdateApp in
            self?.rootView.configure(
                iban: iban?.iban,
                ibanStatus: iban?.status,
                balance: iban?.availableBalance,
                needUpdateApp: needUpdateApp
            )
        }

        model.onAppStore = { [unowned self] in
            showDownloadAppAlert()
        }

        model.onUpdatePhoneNumber = { [unowned self] phoneNumber in
            rootView.configure(phoneNumber: phoneNumber)
        }

        rootView.cardHubHeaderView.onExchange = { [unowned self] in
            self.onExhange?()
        }

        rootView.cardHubHeaderView.onSettings = { [unowned self] in
            self.model.manageCard()
        }

        rootView.onManageCard = { [unowned self] in
            self.model.manageCard()
        }

        rootView.onClose = { [unowned self] in
            self.dismiss(animated: true)
        }

        rootView.onSupport = { [unowned self] in
            self.onSupport?()
        }

        rootView.onLogout = { [unowned self] in
            self.onLogout?()
        }

        rootView.onIbanShare = { [unowned self] iban in
            self.share(text: iban)
        }

        rootView.onUpdateApp = onUpdateApp
    }

    private func share(text: String) {
        let activityController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        present(activityController, animated: true, completion: nil)
    }

    private func showDownloadAppAlert() {
        let alertController = UIAlertController(
            title: R.string.soraCard.cardHubManageCardAlertTitle(preferredLanguages: .currentLocale),
            message: R.string.soraCard.cardHubManageCardAlertMessage(preferredLanguages: .currentLocale),
            preferredStyle: .alert
        )
        alertController.addAction(
            UIAlertAction(
                title: R.string.soraCard.commonCancel(preferredLanguages: .currentLocale),
                style: .cancel)
        )
        alertController.addAction(
            UIAlertAction(
                title: R.string.soraCard.commonOk(preferredLanguages: .currentLocale),
                style: .default
            ){ [weak self] _ in
                self?.onManaageAppStore?()
            }
        )
        present(alertController, animated: true)
    }
}
