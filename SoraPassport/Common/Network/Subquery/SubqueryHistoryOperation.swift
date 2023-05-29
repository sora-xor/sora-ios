import RobinHood
import XNetworking

struct SubqueryKmmError: Swift.Error {
    
}

public final class SubqueryHistoryOperation<ResultType>: BaseOperation<ResultType> {
    
    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SubQueryClientForSoraWallet
    private let address: String
    private let count: Int
    private let page: Int
    private var filter: ((TxHistoryItem) -> KotlinBoolean)? = nil

    public init(address: String, count: Int, page: Int, filter: ((TxHistoryItem) -> KotlinBoolean)? = nil) {
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.filter = filter
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)
        let provider = SoraRemoteConfigProvider(client: self.soraNetworkClient,
                                                commonUrl: ApplicationConfig.shared.commonConfigUrl,
                                                mobileUrl: ApplicationConfig.shared.mobileConfigUrl)
        let configBuilder = provider.provide()

        self.subQueryClient = SubQueryClientForSoraWalletFactory().create(soramitsuNetworkClient: self.soraNetworkClient,
                                                                          pageSize: Int32(count),
                                                                          soraRemoteConfigBuilder: configBuilder)
        self.address = address
        self.count = count
        self.page = page

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

        //TODO: delete after kotlin 1.7.0 released, now we should call method from main queue
        DispatchQueue.main.async {
            self.subQueryClient.getTransactionHistoryPaged(address: self.address,
                                                           page: Int64(self.page),
                                                           filter: self.filter,
                                                           completionHandler: { [self] requestResult, error in
                if let error = error {
                    self.result = .failure(error)
                    semaphore.signal()
                    return
                }

                guard let data = requestResult as? ResultType else {
                    self.result = .failure(SubqueryKmmError())
                    semaphore.signal()
                    return
                }

                if self.isCancelled {
                    return
                }
                semaphore.signal()
                self.result = .success(data)
            })
        }

        semaphore.wait()
    }
}
