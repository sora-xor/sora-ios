import RobinHood
import XNetworking
import Foundation

public final class SubqueryConfigInfoOperation<ResultType>: BaseOperation<ResultType> {

    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let configBuilder: SoraRemoteConfigBuilder

    public override init() {
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)
        let provider = SoraRemoteConfigProvider(client: self.soraNetworkClient,
                                                commonUrl: ApplicationConfig.shared.commonConfigUrl,
                                                mobileUrl: ApplicationConfig.shared.mobileConfigUrl)
        configBuilder = provider.provide()

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

            self.configBuilder.getConfig(completionHandler: { [self] config, error in

                if let data = config as? ResultType {
                    optionalCallResult = .success(data)
                }

                semaphore.signal()

                result = optionalCallResult
            })
        }

        semaphore.wait()
    }
}
