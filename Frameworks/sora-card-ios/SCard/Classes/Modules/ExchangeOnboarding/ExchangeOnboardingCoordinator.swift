import UIKit
import SoraUIKit

class ExchangeOnboardingCoordinator {

    private let service: ExchangeService

    private let onboardingModel = ExchangeOnboardingModel()

    private weak var rootViewController: UIViewController?

    private let navigationController: UINavigationController = {
        let navigationVC = SCNavigationViewController()
        navigationVC.view.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        let color = SoramitsuUI.shared.theme.palette.color(.fgPrimary)
        navigationVC.navigationBar.titleTextAttributes = [.foregroundColor: color]
        return navigationVC
    }()

    init(service: ExchangeService) {
        self.service = service
    }

    @MainActor
    func start(in rootViewController: UIViewController) {
        self.rootViewController = rootViewController

        navigationController.viewControllers = []

        rootViewController.present(navigationController, animated: true)
        navigationController.startLoader()

        checkExchangeStatus()
    }
    
    @MainActor
    private func showOnboardingEmploymentStatus() {
        guard navigationController.viewControllers.isEmpty else { return }
        navigationController.startLoader()
        let model = EmploymentStatusViewModel(employmentStatus: onboardingModel.employmentStatus)
        model.onContinue = { [weak self] employmentStatus in
            self?.onboardingModel.employmentStatus = employmentStatus
            self?.showOnboardingVolume()
        }
        let viewController = EmploymentStatusViewController(viewModel: model)
        navigationController.pushViewController(viewController, animated: true)
        navigationController.stopLoader()
    }

    @MainActor
    private func showOnboardingVolume() {
        let model = ExchangeOnboardingVolumeViewModel(service: service, volume: onboardingModel.volume)
        model.onContinue = { [weak self] volume in
            self?.onboardingModel.volume = volume
            self?.showOnboardingReason()
        }
        let viewController = ExchangeOnboardingVolumeViewController(viewModel: model)
        navigationController.pushViewController(viewController, animated: true)
    }

    @MainActor
    private func showOnboardingReason() {
        let model = ExchangeOnboardingReasonViewModel(service: service, model: onboardingModel)
        model.onContinue = { [weak self] in
            self?.showOnboardingSource()
        }
        let viewController =  ExchangeOnboardingReasonViewController(viewModel: model)
        navigationController.pushViewController(viewController, animated: true)
    }

    @MainActor
    private func showOnboardingSource() {
        let model = ExchangeOnboardingSourceViewModel(service: service, model: onboardingModel)
        model.onContinue = { [weak self] in
            self?.checkExchangeStatus()
        }
        model.onAlreadyOnboarded = { [weak self] in
            DispatchQueue.main.async {
                self?.showExchange()
            }
        }
        model.onOnboardingAlreadyStarted = { [weak self] in
            DispatchQueue.main.async {
                self?.showStatus()
            }
        }
        let viewController =  ExchangeOnboardingSourceViewController(viewModel: model)
        navigationController.pushViewController(viewController, animated: true)
    }

    @MainActor
    private func showStatus() {
        let model = ExchangeOnboardingStatusViewModel(service: service, model: onboardingModel)
        let viewController = ExchangeOnboardingStatusViewController(viewModel: model)

        model.onSupport = { [weak self] in
            self?.showSupport()
        }

        model.onClose = { [weak viewController] in
            viewController?.dismiss(animated: true)
        }

        model.onExchange = { [weak self] in
            self?.showExchange()
        }

        navigationController.pushViewController(viewController, animated: true)
    }

    private func showSupport() {
        let url = URL(string: "https://t.me/soracardofficial")!
        let webViewController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        navigationController.pushViewController(webViewController, animated: true)
    }

    private func checkExchangeStatus() {
        Task {
            switch await service.onboarded() {
            case .success(let response):
                guard let response = response else { return }
                await navigationController.stopLoader()

                switch response.verificationStatus {
                case .pending, .rejected:
                    await showStatus()
                case .accepted:
                    await showExchange()
                }
                
            case .failure(let error):
                await navigationController.stopLoader()
                if error.status == .notFound {
                    await showOnboardingEmploymentStatus()
                } else {
                    print(error.localizedDescription)
                    await navigationController.stopLoader()
                    await navigationController.dismiss(animated: true)
                }
            }
        }
    }

    @MainActor
    private func showExchange() {
        navigationController.startLoader()
        Task { [weak self] in
            let result = await self?.service.userIframe(type: .deposit)
            await MainActor.run { self?.navigationController.stopLoader() }
            switch result {
            case .success(let response):
                guard let urlStr = response?.url, let url = URL(string: urlStr) else {
                    self?.showAlert(
                        title: R.string.soraCard.commonErrorGeneralTitle(),
                        message: response?.statusDescription ?? ""
                    )
                    return
                }
                await MainActor.run {
                    self?.show(url: url)
                }
            case .failure(let error):
                self?.showAlert(
                    title: R.string.soraCard.commonErrorGeneralTitle(),
                    message: error.localizedDescription
                )
            case .none:
                ()
            }
        }
    }

    @MainActor
    private func show(url: URL) {
        let request = URLRequest(url: url)
        let webViewController = WebViewController(
            configuration: .init(),
            request: request
        )
        navigationController.pushViewController(webViewController, animated: true)
    }


    func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            .init(
                title: R.string.soraCard.commonClose(preferredLanguages: .currentLocale),
                style: .cancel,
                handler: { [weak self] _ in
                    self?.navigationController.dismiss(animated: true)
                }
            )
        )
        (navigationController.topViewController ?? navigationController).present(alert, animated: true)
    }
}
