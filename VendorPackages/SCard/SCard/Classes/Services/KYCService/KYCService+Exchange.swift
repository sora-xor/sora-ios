//extension SCKYCService {
//
//    func onboardUser() async -> Result<SCOnboardUserResponse?, NetworkingError> {
////        let client = SCAPIClient(
////            baseURL: URL(string: "https://cryptogatewaytest.paywings.io/whitelabel")!,
////            baseAuth: "",
////            bearerProvider: nil
////        )
//
//        let postData = SCOnboardUserRequest(
//            personID: "00000000-0000-0000-0000-000000000000",
//            referenceID: "",
//            expectedVolume: .k10,
//            openingReason: [.holding],
//            sourceOfFunds: [.salary]
//        )
//
//        let body = (try? JSONEncoder().encode(postData)) ?? Data()
//        let request = APIRequest(method: .get, endpoint: SCEndpoint.onboardUser, body: body)
//
//        return await client.performDecodable(request: request, withAuthorization: false)
//    }
//
//    struct SCOnboardUserRequest: Codable {
//        let personID: String
//        let referenceID: String
//        let expectedVolume: SCExchangeOnboarding.ExpectedVolume
//        let openingReason: [SCExchangeOnboarding.OpeningReason]
//        let sourceOfFunds: [SCExchangeOnboarding.SourceOfFunds]
//
//        enum CodingKeys: String, CodingKey {
//            case personID = "PersonID"
//            case referenceID = "ReferenceID"
//            case expectedVolume = "ExpectedVolume"
//            case openingReason = "OpeningReason"
//            case sourceOfFunds = "SourceOfFunds"
//        }
//    }
//
//    struct SCOnboardUserResponse: Codable {
//        let statusCode: Int
//        let referenceID: String
//        let callerReferenceID: String
//        let statusDescription: String
//
//        enum CodingKeys: String, CodingKey {
//            case statusCode = "StatusCode"
//            case referenceID = "ReferenceID"
//            case callerReferenceID = "CallerReferenceID"
//            case statusDescription = "StatusDescription"
//        }
//    }
//}
