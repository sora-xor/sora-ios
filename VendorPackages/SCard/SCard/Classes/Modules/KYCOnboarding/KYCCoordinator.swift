import Foundation
import SafariServices
import UIKit
import SoraUIKit

final class KYCCoordinator {

    private let addressProvider: () -> String
    private let service: KYCService
    private let storage: SCStorage
    private let onReceiveController: (UIViewController) -> Void
    private let onSwapController: (UIViewController) -> Void
    private let exchangeCoordinator: ExchangeOnboardingCoordinator

    init(
        exchangeCoordinator: ExchangeOnboardingCoordinator,
        addressProvider: @escaping () -> String,
        service: KYCService,
        storage: SCStorage,
        onSwapController: @escaping (UIViewController) -> Void,
        onReceiveController: @escaping (UIViewController) -> Void
    ) {
        self.exchangeCoordinator = exchangeCoordinator
        self.addressProvider = addressProvider
        self.service = service
        self.storage = storage
        self.onSwapController = onSwapController
        self.onReceiveController = onReceiveController
    }

    private weak var rootViewController: UIViewController?
    private let navigationController = SCNavigationViewController()

    func start(in rootViewController: UIViewController) async {
        storage.set(isHidden: false)
        self.rootViewController = rootViewController

        await MainActor.run {
            configureNavigationController()
            navigationController.viewControllers = []
            navigationController.stopLoader()
        }

        switch await service.verionsChangesNeeded() {
        case .major, .minor, .patch:
            await showUpdateVersion()
        case .none:
            await openSCard()
        }
    }

    private func configureNavigationController() {
        let color = SoramitsuUI.shared.theme.palette.color(.fgPrimary)
        navigationController.view.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        navigationController.navigationBar.titleTextAttributes = [.foregroundColor: color]
    }

    private func pushViewController(_ viewController: UIViewController, animated: Bool = true) {
        navigationController.pushViewController(viewController, animated: animated)
        navigationController.stopLoader()
    }

    private func openSCard() async {
        // TODO: present loading creeen

        if await canShowHardhub() {
            await MainActor.run {
                showCardHub()
            }
            return

        } else if await navigationController.presentingViewController == nil {
            await rootViewController?.present(navigationController, animated: true)
            await navigationController.startLoader()
        }

        let data = await KYCUserDataService(service: service).fetchUserData() ?? KYCUserDataModel()

        await service.updateFees()

        DispatchQueue.main.async {
            self.service.startKYCStatusRefresher()
        }

        if service.isUserSignIn() {
            checkUserStatus(data: data)
        } else {
            await MainActor.run { [weak self] in
                self?.showLogin(data: data)
            }
        }
    }

    private func showUpdateVersion() async {
        let url = URL(string: service.config.appStoreUrl)!
        let webViewController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        await rootViewController?.present(webViewController, animated: true)
    }

    private func showXOne() {
        Task { [weak self] in
            guard let self = self else { return }
            let isXOneWidgetAailable = await self.service.isXOneWidgetAailable()

            await MainActor.run {
                if isXOneWidgetAailable {
                    let viewController = XOneViewController(viewModel:
                            .init(address: self.addressProvider(), service: self.service)
                    )
                    self.pushViewController(viewController)
                } else {
                    let viewController = XOneBlockedViewController()
                    viewController.onAction = { [weak self] in
                        self?.navigationController.popViewController(animated: true)
                    }

                    viewController.onUnsupportedCountries = { [weak self] in
                        self?.showUnsupportedCountries()
                    }
                    self.pushViewController(viewController)
                }
            }
        }
    }

    private func showLogin(data: KYCUserDataModel) {

        let viewController = LoginViewController(data: data)

        viewController.onUnsupportedCountries = { [weak self] in
            self?.showUnsupportedCountries()
        }

        viewController.onLogin = { [weak self] in
            self?.showTermsAndConditions(data: data)
        }
        pushViewController(viewController)
    }

    private func showUnsupportedCountries() {
        show(url: URL(string: "https://soracard.com/blacklist")!)
    }

    private func showTermsAndConditions(data: KYCUserDataModel) {
        let viewModel = KYCTermsConditionsViewModel()
        let viewController = KYCTermsConditionsViewController(viewModel: viewModel)

        viewModel.onBlacklistedCountries = { [weak self] in
            self?.show(url: URL(string: "https://soracard.com/blacklist")!)
        }

        viewModel.onGeneralTerms = { [weak self] in
            self?.show(url: URL(string: "https://soracard.com/terms/")!)
        }

        viewModel.onPrivacy = { [weak self] in
            self?.show(url: URL(string: "https://soracard.com/privacy/")!)
        }

        viewModel.onAccept = { [weak self] in
            if self?.service.isUserSignIn() ?? false {
                self?.checkUserStatus(data: data)
            } else {
                self?.showEnterPhone(data: data)
            }
        }

        pushViewController(viewController)
    }

    private func show(url: URL) {
        let request = URLRequest(url: url)
        let webViewController = WebViewController(
            configuration: .init(),
            request: request
        )
        pushViewController(webViewController)
    }

    private func showEnterPhone(data: KYCUserDataModel) {
        let viewModel = KYCEnterPhoneViewModel(service: service, data: data)

        viewModel.onCountry = { [unowned self, unowned viewModel] in
            showCountryList() { selectedCountry in
                viewModel.onCountrySelected(selectedCountry)
            }
        }

        viewModel.onContinue = { [unowned self] in
            showEnterPhoneCode(data: data)

        }
        let viewController = KYCEnterPhoneViewController(viewModel: viewModel)
        pushViewController(viewController)
    }

    private func showCountryList(_ onCountrySelected: @escaping (SCCountry) -> Void) {
        let viewController = CountryList(service: service)
        viewController.onCountrySelected = { [unowned self] selectedCountry in
            navigationController.popViewController(animated: true)
            onCountrySelected(selectedCountry)
        }
        pushViewController(viewController)
    }

    private func showEnterPhoneCode(data: KYCUserDataModel) {
        let viewModel = KYCEnterPhoneCodeViewModel(data: data, service: service)
        viewModel.onUserRegistration = { [unowned self] data in
            showEnterName(data: data)
        }

        viewModel.onUserNotRegistred = { [unowned self] data in
            showUserNotRegistred(data: data)
        }

        viewModel.onSignInSuccessfully = { [unowned self] data in
            checkUserStatus(data: data)
        }

        let viewController = KYCEnterPhoneCodeViewController(viewModel: viewModel)
        pushViewController(viewController)

        viewModel.onEmailVerification = { [unowned self, weak viewController] data in
            showEmailVerification(data: data)
            viewController?.removeFromParent()
        }
    }

    private func showUserNotRegistred(data: KYCUserDataModel) {
        let viewController = KYCNotRegistredController(data: data)
        viewController.onTryAnotherNumber = { [unowned self] in
            let enterPhoneViewController = self.navigationController.viewControllers.first {
                $0 is KYCEnterPhoneViewController
            } ?? .init()
            self.navigationController.popToViewController(enterPhoneViewController, animated: true)
        }

        viewController.onRegister = { [unowned self] in
            let enterPhoneViewController = self.navigationController.viewControllers.first {
                $0 is KYCEnterPhoneViewController
            } ?? .init()
            self.navigationController.popToViewController(enterPhoneViewController, animated: true)
        }
        pushViewController(viewController)
    }

    private func showEnterName(data: KYCUserDataModel) {
        let viewModel = KYCEnterNameViewModel(data: data)
        viewModel.onContinue = { [unowned self] data in
            showEnterEmail(data: data)

        }
        let viewController = KYCEnterNameViewController(viewModel: viewModel)
        pushViewController(viewController)
    }

    private func showEnterEmail(data: KYCUserDataModel) {
        let viewModel = KYCEnterEmailViewModel(data: data, service: service)
        viewModel.onContinue = { [unowned self] data in
            showEmailVerification(data: data)
        }
        let viewController = KYCEnterEmailViewController(viewModel: viewModel)
        pushViewController(viewController)
    }

    private func showEmailVerification(data: KYCUserDataModel) {
        let viewModel = KYCEnterEmailCodeViewModel(data: data, service: service)
        viewModel.onContinue = { [unowned self] data in
            checkUserStatus(data: data)
        }

        viewModel.onChangeEmail = { [unowned self] in
            if data.isEmailSent {
                self.showEnterEmail(data: data)
            } else {
                navigationController.popViewController(animated: true)
            }
        }
        
        let viewController = KYCEnterEmailCodeViewController(viewModel: viewModel)
        pushViewController(viewController)
    }

    private func checkUserStatus(data: KYCUserDataModel) {
        Task {

            await service.updateKycState()

            await MainActor.run { [weak self] in
                guard let self else { return }

                let kycLastState = self.service.currentUserState
                if kycLastState.verificationStatus == .accepted {
                    self.showCardHub()
                    return
                }

                switch kycLastState.kycStatus {

                case .notStarted, .none:
                    self.showGetPrepared(data: data)
                case .started, .failed:
                    self.showGetPrepared(data: data)

                case .completed, .retry, .rejected:
                    if self.storage.isKYCRety() {
                        self.showGetPrepared(data: data)
                    } else {
                        self.showStatus(data: data)
                    }

                case .successful:
                    () // handled earyer verificationStatus == .accepted
                }
            }
        }
    }

    private func canShowHardhub() async -> Bool {
        if service.currentUserState.userStatus == .none {
            await service.updateKycState()
        }
        return service.currentUserState.userStatus == .successful
    }

    private func showGetPrepared(data: KYCUserDataModel){
        let viewModel = KYCSummaryViewModel(service: service)
        viewModel.onContinue = { [unowned self] in
            startKYC(data: data)
        }

        let viewController = KYCSummaryViewController(viewModel: viewModel)
        pushViewController(viewController)

        viewModel.onClose = { [unowned viewController] in
            viewController.navigationController?.dismiss(animated: true)
        }

        viewModel.onLogout = { [weak self, unowned viewController] in
            self?.showLogoutAlert(in: viewController)
        }
    }

    private func startKYC(data: KYCUserDataModel) {
        let viewModel = KYCOnboardingViewModel(data: data, service: service, storage: storage)
        viewModel.onContinue = { [unowned self] data in
            showStatus(data: data)
        }
        let viewController = KYCOnboardingViewController(viewModel: viewModel)
        pushViewController(viewController)
        storage.set(isRety: false)
    }

    private func showStatus(data: KYCUserDataModel) {
        let viewModel = KYCStatusViewModel(data: data, service: service)

        let viewController = KYCStatusViewController(viewModel: viewModel)

        viewModel.onClose = { [unowned viewController] in
            viewController.navigationController?.dismiss(animated: true)
        }

        viewModel.onRetry = { [weak self] in
            Task { [weak self] in await self?.retryKYC() }
        }

        viewModel.onLogout = { [weak self] in
            self?.showLogoutAlert(in: viewController)
        }

        viewModel.onSupport = { [weak self] in
            self?.showSupport()
        }

        pushViewController(viewController)
    }

    private func showCardHub() {

        let viewController = CardHubViewController(model: .init(service: service))

        viewController.onExhange = { [weak self, weak viewController] in
            guard let viewController = viewController else { return }
            self?.showExhange(in: viewController)
        }
        viewController.onLogout = { [weak self, weak viewController] in
            guard let viewController = viewController else { return }
            self?.showLogoutAlert(in: viewController)
        }
        viewController.onSupport = { [weak viewController] in
            let url = URL(string: "https://t.me/soracardofficial")!
            let webViewController = WebViewFactory.createWebViewController(for: url, style: .automatic)
            viewController?.present(webViewController, animated: true)
        }
        viewController.onUpdateApp = { [weak self, weak viewController] in
            guard let self = self else { return }
            let url = URL(string: self.service.config.appStoreUrl)!
            let webViewController = WebViewFactory.createWebViewController(for: url, style: .automatic)
            viewController?.present(webViewController, animated: true)
        }
        viewController.onManaageAppStore = { [weak self, weak viewController] in
            let url = URL(string: "https://apps.apple.com/app/sora-card/id6466728323")!
            let webViewController = WebViewFactory.createWebViewController(for: url, style: .automatic)
            viewController?.present(webViewController, animated: true)
        }

        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(viewController)

        if self.navigationController.presentationController != nil {
            self.navigationController.dismiss(animated: true) { [weak self] in
                self?.rootViewController?.present(containerView, animated: true)
            }
        } else {
            rootViewController?.present(containerView, animated: true)
        }
    }

    private func showExhange(in viewController: UIViewController) {
        Task {
            await exchangeCoordinator.start(in: viewController)
        }
    }

    private func showSupport() {
        let url = URL(string: "https://t.me/soracardofficial")!
        let webViewController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        navigationController.pushViewController(webViewController, animated: true)
    }

    private func showLogoutAlert(in viewController: UIViewController) {
        let alertController = UIAlertController(
            title: R.string.soraCard.cardHubSettingsLogoutTitle(preferredLanguages: .currentLocale),
            message: R.string.soraCard.cardHubSettingsLogoutDescription(preferredLanguages: .currentLocale),
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: R.string.soraCard.commonCancel(preferredLanguages: .currentLocale), style: .cancel))
        alertController.addAction(
            UIAlertAction(title: R.string.soraCard.cardHubSettingsLogoutButton(preferredLanguages: .currentLocale) , style: .destructive
        ) { [weak self, viewController] _ in
            self?.service.logout()
            self?.storage.set(isRety: false)
            viewController.dismiss(animated: true)
        })
        viewController.present(alertController, animated: true)
    }

    private func retryKYC() async {
        storage.set(isRety: true)

        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.showGetPrepared(data: .init())
            self.navigationController.viewControllers = [self.navigationController.viewControllers.last!]
        }
    }

    private func resetKYC() async {

        storage.set(isRety: false)
        service.logout()

        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.showGetPrepared(data: .init())
            self.navigationController.viewControllers = [self.navigationController.viewControllers.last!]
        }
    }

    private func showReceiveController() {
        onReceiveController(navigationController)
    }

    private func showSwapController() {
        onSwapController(navigationController)
    }
}

enum WebPresentableStyle {
    case automatic
    case modal
}

final class WebViewFactory {
    static func createWebViewController(for url: URL, style: WebPresentableStyle) -> UIViewController {
        let webController = SFSafariViewController(url: url)
        webController.preferredControlTintColor = .black
        webController.preferredBarTintColor = .white

        switch style {
        case .modal:
            webController.modalPresentationStyle = .overFullScreen
        default:
            break
        }

        return webController
    }
}
