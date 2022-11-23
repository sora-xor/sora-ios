import FearlessUtils
import Foundation
import RobinHood

protocol SubqueryHistoryOperationFactoryProtocol {
    func createOperation(
        address: String,
        count: Int,
        after: String
    ) -> BaseOperation<SubqueryHistoryData>
}

final class SubqueryHistoryOperationFactory {
    let url: URL
    let filter: WalletHistoryFilter

    init(url: URL, filter: WalletHistoryFilter) {
        self.url = url
        self.filter = filter
    }
}
