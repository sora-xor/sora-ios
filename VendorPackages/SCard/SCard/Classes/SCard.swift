import PayWingsOAuthSDK
import SoraUIKit

public class SCard {

    public static let currentSDKVersion = "2.2.4"
    static let techSupportLink = "techsupport@soracard.com"

    public static var shared: SCard?

    internal let service: KYCService
    private let config: Config
    private let coordinator: KYCCoordinator
    private let exchangeCoordinator: ExchangeOnboardingCoordinator
    private let client: APIClient
    private let storage: SCStorage = .shared
    private let addressProvider: () -> String

    public struct Config {
        public let appStoreUrl: String
        public let backendUrl: String
        public let pwAuthDomain: String
        public let pwApiKey: String
        public let appPlatformId: String
        public let recaptchaKey: String
        public let kycUrl: String
        public let kycUsername: String
        public let kycPassword: String
        public let xOneEndpoint: String
        public let xOneId: String
        public let environmentType: EnvironmentType
        public let themeMode: SoramitsuThemeMode

        public init(
            appStoreUrl: String,
            backendUrl: String,
            pwAuthDomain: String,
            pwApiKey: String,
            appPlatformId: String,
            recaptchaKey: String,
            kycUrl: String,
            kycUsername: String,
            kycPassword: String,
            xOneEndpoint: String,
            xOneId: String,
            environmentType: EnvironmentType,
            themeMode: SoramitsuThemeMode
        ) {
            self.appStoreUrl = appStoreUrl
            self.backendUrl = backendUrl
            self.pwAuthDomain = pwAuthDomain
            self.pwApiKey = pwApiKey
            self.appPlatformId = appPlatformId
            self.recaptchaKey = recaptchaKey
            self.kycUrl = kycUrl
            self.kycUsername = kycUsername
            self.kycPassword = kycPassword
            self.xOneEndpoint = xOneEndpoint
            self.xOneId = xOneId
            self.environmentType = environmentType
            self.themeMode = themeMode
        }

        public enum EnvironmentType: String {
            case test
            case prod

            var pwType: PayWingsOAuthSDK.EnvironmentType {
                switch self {
                case .test:
                    return .TEST
                case .prod:
                    return .PRODUCTION
                }
            }
        }
    }

    public init(
        addressProvider: @escaping () -> String,
        config: Config,
        onReceiveController: @escaping (UIViewController) -> Void,
        onSwapController: @escaping (UIViewController) -> Void,
        logLevels: NetworkingLogLevel = .info
    ) {
        self.config = config
        self.addressProvider = addressProvider

        let bearerProvider = PayWingsOAuthProvider()

        client = .init(
            baseURL: URL(string: config.backendUrl)!,
            baseAuth: "",
            bearerProvider: bearerProvider,
            logLevels: logLevels
        )
        service = KYCService(client: client, config: config)

        let exchangeService = ExchangeService(client: client, config: config)
        exchangeCoordinator = ExchangeOnboardingCoordinator(service: exchangeService)

        coordinator = KYCCoordinator(
            exchangeCoordinator: exchangeCoordinator,
            addressProvider: addressProvider,
            service: service,
            storage: storage,
            onSwapController: onSwapController,
            onReceiveController: onReceiveController
        )

        Task {
            _ = await service.fetchVersion()
            if SCStorage.shared.isFirstLaunch() {
                logout()
                SCStorage.shared.setAppLaunched()
            } else {
                await service.updateKycState()
            }
        }
    }

    public var selectedLocalization: String = "en" {
        didSet {
            LocalizationManager.shared.selectedLocalization = selectedLocalization
        }
    }

    public func start(in vc: UIViewController) {
        Task { await coordinator.start(in: vc) }
    }

    public func showExchange(in vc: UIViewController) {
        Task { await exchangeCoordinator.start(in: vc) }
    }

    public var userStatusStream: AsyncStream<KYCUserStatus> {
        service.userStatusStream
    }

    public func userStatus() async -> KYCUserStatus? {
        await service.userStatus()
    }

    public var isUserSignIn: Bool {
        service.isUserSignIn()
    }

    public var currentUserState: KYCUserStatus {
        service.currentUserState.userStatus
    }

    public var hasIban: Bool {
        service.currentUserIban != nil
    }

    public var isSCBannerHidden: Bool {
        get { storage.isSCBannerHidden() }
        set { storage.set(isHidden: newValue) }
    }

    public func xOneViewController(address: String) -> UIViewController {
        return XOneViewController(viewModel: .init(address: address, service: service))
    }

    public var configuration: String {
        config.debugDescription
    }

    public func logout() {
        storage.set(isRety: false)
        service.logout()
    }
}

extension SCard.Config: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        SCard.Config
        backendUrl: \(backendUrl)
        pwAuthDomain: \(pwAuthDomain)
        pwApiKey: \(pwApiKey)
        appPlatformId: \(appPlatformId)
        recaptchaKey: \(recaptchaKey)
        kycUrl: \(kycUrl)
        kycUsername: \(kycUsername)
        kycPassword: \(kycPassword)
        xOneEndpoint: \(xOneEndpoint)
        xOneId: \(xOneId)
        environmentType: \(environmentType)
        themeMode: \(themeMode)
        """
    }
}
