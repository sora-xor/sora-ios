import PayWingsOAuthSDK

final class PayWingsOAuthProvider: BearerProvider {

    private var authClient: OAuthServiceProtocol? {
        PayWingsOAuthClient.instance()
    }

    func bearer(
        url: String,
        method: HttpRequestMethod
    ) async -> String? {

        guard authClient?.isUserSignIn() ?? false else {
            return nil
        }

        // TODO: use dpop
        let (accessToken, _) = await withCheckedContinuation { continuation in
            authClient?.getNewAuthorizationData(
                methodUrl: url,
                httpRequestMethod: method
            ) { authData in
                if authData.userSignInRequired ?? false {
                    print("SCAPIClient userSignInRequired")
                }
                if let errorData = authData.errorData {
                    print("SCAPIClient error: \(errorData.errorMessage ?? "") \(errorData.error.description)")
                }
                continuation.resume(returning: (authData.accessTokenData?.accessToken, authData.dpop))
            }
        }
        return accessToken
    }
}
