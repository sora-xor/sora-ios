import SSFCloudStorage

protocol SignInGoogle: AnyObject {
    var cloudStorageService: CloudStorageServiceProtocol? { get set }
    var isSignedInGoogleAccount: Bool { get }
    func signInToGoogleIfNeeded(completion: @escaping (CloudStorageAccountState) -> Void)
}

extension SignInGoogle {
    var isSignedInGoogleAccount: Bool {
        cloudStorageService?.isUserAuthorized ?? false
    }
    
    func signInToGoogleIfNeeded(completion: @escaping (CloudStorageAccountState) -> Void) {
        cloudStorageService?.signInIfNeeded(completion: completion)
    }
}
