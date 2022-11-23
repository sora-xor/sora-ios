import RobinHood
import XNetworking
import Foundation

public final class SubqueryApyInfoOperation<ResultType>: BaseOperation<ResultType> {

    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SoraWalletBlockExplorerInfo
    private let baseUrl: URL

    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)

        self.subQueryClient = SoraWalletBlockExplorerInfo(networkClient: self.soraNetworkClient, baseUrl: baseUrl.absoluteString)

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
            self.subQueryClient.getSpApy(url: self.baseUrl.absoluteString,
                                         caseName: ApplicationConfig.shared.caseName,
                                         completionHandler: { [self] requestResult, error in
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
