import RobinHood
import XNetworking

public final class SubqueryHistoryOperation<ResultType>: BaseOperation<ResultType> {
    
    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SubQueryClientForSoraWallet
    private let address: String
    private let count: Int
    private let page: Int

    public init(address: String, count: Int, page: Int) {
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)

        self.subQueryClient = SubQueryClientForSoraWalletFactory().create(soramitsuNetworkClient: self.soraNetworkClient,
                                                                          baseUrl: ApplicationConfig.shared.subqueryUrl.absoluteString,
                                                                          pageSize: Int32(count))
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
                                                           networkName: "Sora",
                                                           page: Int64(self.page),
                                                           url: ApplicationConfig.shared.subqueryUrl.absoluteString,
                                                           filter: nil,
                                                           completionHandler: { [self] requestResult, error in
                guard let data = requestResult as? ResultType else { return }

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
