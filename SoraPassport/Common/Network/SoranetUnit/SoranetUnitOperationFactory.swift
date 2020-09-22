import Foundation
import RobinHood

final class SoranetUnitOperationFactory: SoranetUnitOperationFactoryProtocol {
    func withdrawProofOperation(_ urlTemplate: String,
                                info: WithdrawProofInfo) -> NetworkOperation<WithdrawProofData?> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildParameterURL(info.accountId)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<WithdrawProofData?> { data in
            let statusData = try JSONDecoder().decode(ResultData<[WithdrawProofData]>.self, from: data)

            guard statusData.status.isSuccess else {
                throw ResultStatusError(statusData: statusData.status)
            }

            let transactionHash = info.intentionHash.soraHex

            return statusData.result?.first { $0.intentionHash.lowercased() == transactionHash }
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
