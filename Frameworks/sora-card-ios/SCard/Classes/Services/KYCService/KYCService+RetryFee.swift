extension KYCService {
    func fees() async -> Result<KYCRetryFee, NetworkingError> {
        let request = APIRequest(method: .get, endpoint: SCEndpoint.fees)
        return await client.performDecodable(request: request, withAuthorization: false)
    }

    func updateFees() async {
        switch await fees() {
        case .success(let respose):
            self.retryFeeCache = respose.retryFee
            self.applicationFeeCache = respose.applicationFee
        case .failure(let error):
            print(error)
        }
    }
}

struct KYCRetryFee: Codable {
    let applicationFee: String
    let retryFee: String

    enum CodingKeys: String, CodingKey {
        case applicationFee = "application_fee"
        case retryFee = "retry_fee"
    }
}
