import RobinHood
import XNetworking
import Foundation

public final class SubqueryReferralRewardsOperation<ResultType>: BaseOperation<ResultType> {

    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SoraWalletBlockExplorerInfo
    private let address: String
    private let baseUrl: URL
    private let count: Int

    public init(address: String, count: Int = 1000, baseUrl: URL) {
        self.baseUrl = baseUrl
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)
        let provider = SoraRemoteConfigProvider(client: self.soraNetworkClient,
                                                commonUrl: ApplicationConfig.shared.commonConfigUrl,
                                                mobileUrl: ApplicationConfig.shared.mobileConfigUrl)
        let configBuilder = provider.provide()

        self.subQueryClient = SoraWalletBlockExplorerInfo(networkClient: self.soraNetworkClient, soraRemoteConfigBuilder: configBuilder)
        self.address = address
        self.count = count

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

        DispatchQueue.main.async {
            self.subQueryClient.getReferrerRewards(address: self.address, completionHandler: { [self] requestResult, error in
                guard let data = requestResult as? ResultType else { return }

                if isCancelled {
                    return
                }
                semaphore.signal()

                result = .success(data)
            })
        }

        semaphore.wait()
    }
}
