extension KYCService {
    func kycAttempts() async -> Result<KYCAtempts, NetworkingError> {
        let request = APIRequest(method: .get, endpoint: SCEndpoint.kycAttemptCount)
        return await client.performDecodable(request: request)
    }
}

struct KYCAtempts: Codable {
    let total: Int64
    let completed: Int64
    let rejected: Int64
    let totalFreeAttempts: Int64
    let freeAttemptsLeft: Int64
    let hasFreeAttempts: Bool

    enum CodingKeys: String, CodingKey {
        case total
        case completed
        case rejected
        case totalFreeAttempts = "total_free_attempts"
        case freeAttemptsLeft = "free_attempts_left"
        case hasFreeAttempts = "free_attempt"
    }
}
