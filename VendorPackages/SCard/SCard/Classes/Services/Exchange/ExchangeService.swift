import Foundation

final class ExchangeService {

    internal let client: APIClient
    private var isRefreshAccessTokenInProgress = false

    init(client: APIClient, config: SCard.Config) {
        self.client = client
    }

    func onboarded() async -> Result<OnboardedResponse?, NetworkingError> {
        let request = APIRequest(method: .get, endpoint: SCEndpoint.onboarded)
        return await client.performDecodable(request: request)
    }

    func onboardUser(data: ExchangeOnboardingModel) async -> Result<OnboardUserResponse?, NetworkingError> {
        let postData = OnboardUserRequest(
            expectedVolume: data.volume,
            openingReason: data.reasons.compactMap { $1 ? $0 : nil },
            sourceOfFunds: data.sources.compactMap { $1 ? $0 : nil }
        )

        let body = (try? JSONEncoder().encode(postData)) ?? Data()
        let request = APIRequest(method: .post, endpoint: SCEndpoint.onboardUser, body: body)

        return await client.performDecodable(request: request)
    }

    func userIframe(type: IframeType) async -> Result<IframeResponse?, NetworkingError> {
        let postData = IFrameRequest(iframeType: type)
        let body = (try? JSONEncoder().encode(postData)) ?? Data()
        let request = APIRequest(method: .post, endpoint: SCEndpoint.userIframe, body: body)

        return await client.performDecodable(request: request)
    }

    struct OnboardUserRequest: Codable {
        let expectedVolume: ExchangeOnboarding.ExpectedVolume
        let openingReason: [ExchangeOnboarding.OpeningReason]
        let sourceOfFunds: [ExchangeOnboarding.SourceOfFunds]

        enum CodingKeys: String, CodingKey {
            case expectedVolume = "ExpectedVolume"
            case openingReason = "OpeningReason"
            case sourceOfFunds = "SourceOfFunds"
        }
    }

    struct OnboardUserResponse: Codable {
        let statusCode: Int
        let referenceID: String
        let callerReferenceID: String
        let statusDescription: String

        enum CodingKeys: String, CodingKey {
            case statusCode = "StatusCode"
            case referenceID = "ReferenceID"
            case callerReferenceID = "CallerReferenceID"
            case statusDescription = "StatusDescription"
        }
    }

    struct OnboardedResponse: Codable {
        let personId: String
        let updateTime: UInt
        let verificationDescription: String
        let verificationMessage: String
        let verificationStatus: OnboardingStatus

        enum CodingKeys: String, CodingKey {
            case personId = "person_id"
            case updateTime = "update_time"
            case verificationDescription = "verification_description"
            case verificationMessage = "verification_message"
            case verificationStatus = "verification_status"
        }
    }

    enum OnboardingStatus: Int, Codable {
        case pending = 0
        case accepted = 1
        case rejected = 2
    }


    struct IFrameRequest: Codable {
        let iframeType: IframeType

        enum CodingKeys: String, CodingKey {
            case iframeType = "IframeType"
        }
    }

    enum IframeType: Int, Codable {
        case withdrawal = 1
        case deposit = 2
        case exchange = 3
    }

    struct IframeResponse: Codable {
        let statusCode: Int
        let url: String?
        let urlValidTo: String?
        let referenceID: String
        let callerReferenceID: String
        let statusDescription: String

        enum CodingKeys: String, CodingKey {
            case statusCode = "StatusCode"
            case url = "Url"
            case urlValidTo = "UrlValidTo"
            case referenceID = "ReferenceID"
            case callerReferenceID = "CallerReferenceID"
            case statusDescription = "StatusDescription"
        }
    }
}
