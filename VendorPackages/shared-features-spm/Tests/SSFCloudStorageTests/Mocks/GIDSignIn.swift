import SSFCloudStorage
import GoogleAPIClientForREST_Drive

@testable import GoogleSignIn

final class GIDProfileDataMock: GIDProfileData {
    var emailValue = "wallet@example.com"
    var nameValue = "Wallet Owner"

    override var email: String { emailValue }
    override var name: String { nameValue }
}

final class GIDGoogleUserMock: GIDGoogleUser {
    var userIDValue: String? = "google-user-id"
    var scopesValue: [String]? = [kGTLRAuthScopeDriveAppdata]
    let profileValue = GIDProfileDataMock()

    override var userID: String? { userIDValue }
    override var profile: GIDProfileData? { profileValue }
    override var grantedScopes: [String]? { scopesValue }
}

class GIDSignInMock: GIDSignIn {
    override var currentUser: GIDGoogleUser? {
        _currentUser
    }

    var _currentUser: GIDGoogleUser?

    // MARK: - previous sign-in

    var hasPreviousSignInCallsCount: Int = 0
    var hasPreviousSignInReturnValue: Bool = false

    override func hasPreviousSignIn() -> Bool {
        hasPreviousSignInCallsCount += 1
        return hasPreviousSignInReturnValue
    }

    var restorePreviousSignInCallsCount: Int = 0
    var restorePreviousSignInClosure: ((((GIDGoogleUser?, Error?) -> Void)?) -> Void)?
    var restorePreviousSignInWithoutRefreshCallsCount: Int = 0
    var restorePreviousSignInWithoutRefreshClosure: (() -> Bool)?

    override func restorePreviousSignIn(
        completion: ((GIDGoogleUser?, Error?) -> Void)? = nil
    ) {
        restorePreviousSignInCallsCount += 1
        restorePreviousSignInClosure?(completion)
    }

    override func restorePreviousSignInWithoutRefresh() -> Bool {
        restorePreviousSignInWithoutRefreshCallsCount += 1
        return restorePreviousSignInWithoutRefreshClosure?() ?? (_currentUser != nil)
    }

    // MARK: - signIn

    var signInCallsCount: Int = 0
    var signInCalled: Bool {
        signInCallsCount > 0
    }

    var signInReceivedArguments: (
        withPresenting: UIViewController,
        hint: String?,
        additionalScopes: [String]?,
        forceAccountSelection: Bool,
        completion: ((GIDSignInResult?, Error?) -> Void)?
    )?
    var signInClosure: ((
        UIViewController,
        String?,
        [String]?,
        ((GIDSignInResult?, Error?) -> Void)?
    ) -> Void)?

    override func signIn(
        withPresenting presentingViewController: UIViewController,
        hint: String?,
        additionalScopes: [String]?,
        forceAccountSelection: Bool,
        completion: ((GIDSignInResult?, Error?) -> Void)?
    ) {
        signInCallsCount += 1
        signInReceivedArguments = (
            withPresenting: presentingViewController,
            hint: hint,
            additionalScopes: additionalScopes,
            forceAccountSelection: forceAccountSelection,
            completion: completion
        )
        signInClosure?(presentingViewController, hint, additionalScopes, completion)
    }

    // MARK: - signOut

    var signOutCallsCount: Int = 0
    var signOutCalled: Bool {
        signOutCallsCount > 0
    }

    var signOutClosure: (() -> Void)?

    override func signOut() {
        signOutCallsCount += 1
        signOutClosure?()
    }

    // MARK: - disconnect

    var disconnectCompletionCallsCount: Int = 0
    var disconnectCompletionCalled: Bool {
        disconnectCompletionCallsCount > 0
    }

    var disconnectCompletionClosure: ((((Error?) -> Void)?) -> Void)?

    override func disconnect(completion: ((Error?) -> Void)? = nil) {
        disconnectCompletionCallsCount += 1
        disconnectCompletionClosure?(completion)
    }
}
