import RobinHood
import XNetworking
import Foundation

public final class SubqueryFiatInfoOperation<ResultType>: BaseOperation<ResultType> {

    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SoraWalletBlockExplorerInfo
    private let baseUrl: URL

    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)
        let provider = SoraRemoteConfigProvider(client: self.soraNetworkClient,
                                                commonUrl: ApplicationConfig.shared.commonConfigUrl,
                                                mobileUrl: ApplicationConfig.shared.mobileConfigUrl)
        let configBuilder = provider.provide()

        self.subQueryClient = SoraWalletBlockExplorerInfo(networkClient: self.soraNetworkClient, soraRemoteConfigBuilder: configBuilder)

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)

        var optionalCallResult: Result<ResultType, Swift.Error>?

        DispatchQueue.main.async {

            self.subQueryClient.getFiat(completionHandler: { [self] requestResult, error in

                if let data = requestResult as? ResultType {
                    optionalCallResult = .success(data)
                }

                semaphore.signal()

                result = optionalCallResult
            })
        }

        semaphore.wait()
    }
}
