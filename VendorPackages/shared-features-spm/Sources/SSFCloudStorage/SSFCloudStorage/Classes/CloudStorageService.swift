import Foundation
import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import GoogleSignIn
import IrohaCrypto
import SSFModels
import SSFUtils
import TweetNacl

public enum KeystoreConstants {
    public static let nonceLength = 24
    public static let encryptionKeyLength = 32
}

public enum CloudStorageAccountState {
    case authorized
    case notAuthorized
}

/// The Google account whose authorization a service's Drive requests use.
public struct CloudStorageAccountIdentity: Equatable, Sendable {
    /// Google's stable identifier of the account. An email address can be
    /// renamed or reassigned; this cannot.
    public let userID: String
    public let email: String?

    public init(userID: String, email: String? = nil) {
        self.userID = userID
        self.email = email
    }
}

/// A list of backups and the one Google account all of it was read from;
/// nil when that account cannot be named.
public struct CloudStorageBackupListing {
    public let accounts: [OpenBackupAccount]
    public let googleAccount: CloudStorageAccountIdentity?

    public init(accounts: [OpenBackupAccount], googleAccount: CloudStorageAccountIdentity?) {
        self.accounts = accounts
        self.googleAccount = googleAccount
    }
}

public protocol CloudStorageServiceProtocol: AnyObject {
    var isUserAuthorized: Bool { get }
    /// The Google account this service last authorized its Drive requests
    /// with; nil before its first sign-in and after `disconnect()`.
    var currentAccountIdentity: CloudStorageAccountIdentity? { get }
    func signInIfNeeded() async throws -> CloudStorageAccountState
    func getBackupAccounts() async throws -> [OpenBackupAccount]
    func saveBackup(account: OpenBackupAccount, password: String) async throws
    func importBackup(account: OpenBackupAccount, password: String) async throws
        -> OpenBackupAccount
    /// Reads a backup only from the Google account with this user ID: the
    /// one that listed the backup for the user. Throws
    /// `CloudStorageServiceError.accountChanged`, without reading, when
    /// another account (or none that can be named) would serve the request.
    /// Every service implements the binding itself; there is no default.
    func importBackup(
        account: OpenBackupAccount,
        password: String,
        expectedAccountUserID: String
    ) async throws -> OpenBackupAccount
    func deleteBackup(account: OpenBackupAccount) async throws
    func disconnect()

    /// The same operations, returning the Google account that served the
    /// whole operation. A service names the account only when it knows it
    /// for that operation; the defaults below name none.
    func getBackupAccountsNamingAccount() async throws -> CloudStorageBackupListing
    func saveBackupNamingAccount(
        account: OpenBackupAccount,
        password: String
    ) async throws -> CloudStorageAccountIdentity?
    func deleteBackupNamingAccount(
        account: OpenBackupAccount
    ) async throws -> CloudStorageAccountIdentity?
}

public extension CloudStorageServiceProtocol {
    /// A service that cannot name its Google account has none.
    var currentAccountIdentity: CloudStorageAccountIdentity? { nil }

    /// A service without its own naming: the operation runs and no account
    /// is named. Reading `currentAccountIdentity` after the operation would
    /// name whatever account a later operation signed in.
    func getBackupAccountsNamingAccount() async throws -> CloudStorageBackupListing {
        CloudStorageBackupListing(accounts: try await getBackupAccounts(), googleAccount: nil)
    }

    func saveBackupNamingAccount(
        account: OpenBackupAccount,
        password: String
    ) async throws -> CloudStorageAccountIdentity? {
        try await saveBackup(account: account, password: password)
        return nil
    }

    func deleteBackupNamingAccount(
        account: OpenBackupAccount
    ) async throws -> CloudStorageAccountIdentity? {
        try await deleteBackup(account: account)
        return nil
    }
}

/// Lets one operation of a service run at a time, in arrival order.
private actor CloudStorageOperationGate {
    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private var isBusy = false
    private var waiting: [Waiter] = []
    private var nextWaiterID: UInt64 = 0

    /// Returns once the caller holds the gate; the caller then calls
    /// `leave()` exactly once. A task cancelled while it waits leaves the
    /// queue at once and throws `CancellationError` without holding the gate.
    func enter() async throws {
        guard isBusy else {
            isBusy = true
            return
        }
        let id = nextWaiterID
        nextWaiterID &+= 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiting.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func leave() {
        if waiting.isEmpty {
            isBusy = false
        } else {
            waiting.removeFirst().continuation.resume()
        }
    }

    /// A waiter whose task was cancelled. One that was already let in holds
    /// the gate and leaves it itself.
    private func cancel(_ id: UInt64) {
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        waiting.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}

protocol GoogleDriveServiceProtocol: AnyObject {
    var googleDriveService: GoogleService { get }
}

/// What the service needs from Google Sign-In. `GIDSignIn` provides it. The
/// SDK's own types cannot be created outside it, so tests supply this.
public protocol CloudStorageSignInProvider: AnyObject {
    var currentUser: GIDGoogleUser? { get }
    func signInForDrive(
        presenting: UIViewController,
        scopes: [String],
        completion: @escaping (GIDGoogleUser?, Error?) -> Void
    )
    func signOut()
    func disconnect(completion: ((Error?) -> Void)?)
}

extension GIDSignIn: CloudStorageSignInProvider {
    public func signInForDrive(
        presenting: UIViewController,
        scopes: [String],
        completion: @escaping (GIDGoogleUser?, Error?) -> Void
    ) {
        signIn(withPresenting: presenting, hint: nil, additionalScopes: scopes) { result, error in
            completion(result?.user, error)
        }
    }
}

public class CloudStorageService: NSObject, GoogleDriveServiceProtocol {
    public var isUserAuthorized: Bool { singInProvider.currentUser != nil }
    public var currentAccountIdentity: CloudStorageAccountIdentity? {
        identityLock.lock(); defer { identityLock.unlock() }
        return authorizedIdentity
    }
    public var googleDriveService: GoogleService

    /// The account of the authorizer the Drive service holds. The two are
    /// only ever changed together, in `setAuthorizer(for:)`.
    private var authorizedIdentity: CloudStorageAccountIdentity?
    private let identityLock = NSLock()
    /// The Drive service has one authorizer, so the operations of one
    /// service run one after another.
    private let operations = CloudStorageOperationGate()

    private weak var uiDelegate: UIViewController?
    private let singInProvider: CloudStorageSignInProvider
    private let queue: DispatchQueueType
    private let encryptionService: EncryptionServiceProtocol
    private let fileFactory: BackupFileFactoryProtocol

    public init(
        uiDelegate: UIViewController,
        signInProvider: CloudStorageSignInProvider = GIDSignIn.sharedInstance,
        googleDriveService: GoogleService =
            BaseGoogleService(googleService: GTLRDriveService()),
        queue: DispatchQueueType = DispatchQueue.main,
        encryptionService: EncryptionServiceProtocol = EncryptionService(),
        fileFactory: BackupFileFactoryProtocol? = nil
    ) {
        self.uiDelegate = uiDelegate
        singInProvider = signInProvider
        self.googleDriveService = googleDriveService
        self.queue = queue
        self.encryptionService = encryptionService
        self.fileFactory = fileFactory ?? BackupFileFactory(service: encryptionService)
    }

    private func getAppFolderFiles(
        from q: String? = nil,
        withField: Bool = false
    ) async throws -> [GTLRDrive_File] {
        let query = GTLRDriveQuery_FilesList.query()
        query.spaces = "appDataFolder"
        query.fields = withField ? "files(id, name, description)" : nil
        query.q = q

        let results = try await googleDriveService.executeQuery(query)
        let files = (results.file as? GTLRDrive_FileList)?.files ?? []
        return files
    }

    private func getParentFolder() async throws -> String {
        let q = "name = 'backupFolder'"
        let files = try await getAppFolderFiles(from: q)

        if files.isEmpty {
            let fileId = try await createBackupFolder()
            return fileId
        }

        let folderId = files.first?.identifier ?? ""
        return folderId
    }

    private func createBackupFolder() async throws -> String {
        let file = GTLRDrive_File()
        file.name = "backupFolder"
        file.parents = ["appDataFolder"]
        file.mimeType = "application/vnd.google-apps.folder"

        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: nil)
        query.fields = "id"

        let results = try await googleDriveService.executeQuery(query)
        let fileId = (results.file as? GTLRDrive_File)?.identifier ?? ""
        return fileId
    }

    private func executeQueryForMedia(withFileId: String) async throws -> Data {
        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: withFileId)
        let results = try await googleDriveService.executeQuery(query)

        guard let data = (results.file as? GTLRDataObject)?.data else {
            throw CloudStorageServiceError.notFound
        }

        return data
    }
}

// MARK: - CloudStorageServiceProtocol

extension CloudStorageService: CloudStorageServiceProtocol {
    public func signInIfNeeded() async throws -> CloudStorageAccountState {
        try await operations.enter()
        do {
            // A task cancelled while it waited starts nothing.
            try Task.checkCancellation()
            let state = try await authorize(expectedAccountUserID: nil)
            await operations.leave()
            return state
        } catch {
            await operations.leave()
            throw error
        }
    }

    /// Runs one operation: alone on this service, and with one Google
    /// account. The account is the expected one, or else the one the first
    /// authorization finds; every later Drive request of the operation is
    /// authorized for that account only (`authorizeStep`). An account that
    /// cannot be named cannot be held to, so it serves no operation and is
    /// signed out, and the next attempt offers Google's chooser again.
    /// Returns the operation's result and the account that served all of it.
    /// Once Drive has acknowledged the operation, its result stands.
    private func perform<T>(
        expecting expectedAccountUserID: String? = nil,
        _ operation: (_ pinnedUserID: String) async throws -> T
    ) async throws -> (value: T, account: CloudStorageAccountIdentity) {
        try await operations.enter()
        do {
            // A task cancelled while it waited starts nothing.
            try Task.checkCancellation()
            guard let user = try await authorizedUser(expectedAccountUserID: expectedAccountUserID) else {
                throw CloudStorageServiceError.notAuthorized
            }
            guard let account = Self.identity(of: user) else {
                setAuthorizer(for: nil)
                await signOutUnnamed(user)
                throw CloudStorageServiceError.notAuthorized
            }
            let value = try await operation(account.userID)
            await operations.leave()
            return (value, account)
        } catch {
            await operations.leave()
            throw error
        }
    }

    /// Ends the Google session of `user`, an account that cannot be named,
    /// so that the next attempt offers Google's chooser. If another account
    /// has been signed in since, it stays: Google Sign-In changes its session
    /// on the main thread, so the check and the sign-out run there together.
    private func signOutUnnamed(_ user: GIDGoogleUser) async {
        let provider = singInProvider
        await MainActor.run {
            if provider.currentUser === user {
                provider.signOut()
            }
        }
    }

    /// Precedes every Drive request of an operation after its first.
    private func authorizeStep(_ pinnedUserID: String) async throws {
        guard try await authorize(expectedAccountUserID: pinnedUserID) == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }
    }

    /// Every Drive request of this service follows a call of this function.
    /// With an expected user ID, the Drive service is given an authorizer
    /// only when it belongs to that Google account; otherwise it is cleared
    /// and `accountChanged` is thrown, so the request that would follow is
    /// never made with another account.
    private func authorize(
        expectedAccountUserID: String?
    ) async throws -> CloudStorageAccountState {
        try await authorization(expectedAccountUserID: expectedAccountUserID).state
    }

    /// The Google user whose authorizer the Drive service now holds; nil
    /// when none could be authorized.
    private func authorizedUser(expectedAccountUserID: String?) async throws -> GIDGoogleUser? {
        let result = try await authorization(expectedAccountUserID: expectedAccountUserID)
        return result.state == .authorized ? result.user : nil
    }

    private func authorization(
        expectedAccountUserID: String?
    ) async throws -> (state: CloudStorageAccountState, user: GIDGoogleUser?) {
        guard let uiDelegate = uiDelegate else {
            return (.notAuthorized, nil)
        }

        let user: GIDGoogleUser?
        if let current = singInProvider.currentUser {
            user = current
        } else {
            user = try await signIn(uiDelegate: uiDelegate)
        }

        if let expectedAccountUserID {
            guard !expectedAccountUserID.isEmpty,
                  let user,
                  Self.identity(of: user)?.userID == expectedAccountUserID else {
                setAuthorizer(for: nil)
                // An account that cannot be named can never be the expected
                // one; a retry with it would fail the same way.
                if let user, Self.identity(of: user) == nil {
                    await signOutUnnamed(user)
                }
                throw CloudStorageServiceError.accountChanged
            }
        }

        setAuthorizer(for: user)
        return (.authorized, user)
    }

    private func setAuthorizer(for user: GIDGoogleUser?) {
        identityLock.lock(); defer { identityLock.unlock() }
        googleDriveService.set(authorizer: user?.fetcherAuthorizer)
        authorizedIdentity = user.flatMap(Self.identity(of:))
    }

    private static func identity(of user: GIDGoogleUser) -> CloudStorageAccountIdentity? {
        let userID = (user.userID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty else { return nil }
        let email = user.profile?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return CloudStorageAccountIdentity(userID: userID, email: email.isEmpty ? nil : email)
    }

    public func getBackupAccounts() async throws -> [OpenBackupAccount] {
        try await getBackupAccountsNamingAccount().accounts
    }

    /// Both lists (the app's and the browser extension's) are read from one
    /// Google account. If the account changes between them, nothing is
    /// returned.
    public func getBackupAccountsNamingAccount() async throws -> CloudStorageBackupListing {
        let listed = try await perform { pinned -> [OpenBackupAccount] in
            let mobileAccounts = try await self.getBackupAccountsForMobileExtension(pinned: pinned)
            let extensionAccounts = try await self.getBackupAccountsForFearlessExtension(pinned: pinned)

            let filteredExtensionAccounts = extensionAccounts.filter { extensionAccount in
                !mobileAccounts.contains(where: { $0.address == extensionAccount.address })
            }
            return mobileAccounts + filteredExtensionAccounts
        }
        return CloudStorageBackupListing(accounts: listed.value, googleAccount: listed.account)
    }

    public func saveBackup(account: OpenBackupAccount, password: String) async throws {
        _ = try await saveBackupNamingAccount(account: account, password: password)
    }

    public func saveBackupNamingAccount(
        account: OpenBackupAccount,
        password: String
    ) async throws -> CloudStorageAccountIdentity? {
        // The encrypted backup is made in memory for this save alone. No file
        // is shared with another save of the same wallet, so concurrent
        // saves cannot upload or remove each other's backup.
        let data = try fileFactory.createBackupData(from: account, password: password)

        return try await perform { _ -> Void in
            let folderId = try await self.getParentFolder()

            let file = GTLRDrive_File()
            file.name = "\(account.address).json"
            file.descriptionProperty = account.name
            file.parents = ["\(folderId)"]

            let params = GTLRUploadParameters(data: data, mimeType: "application/json")
            params.shouldUploadWithSingleRequest = true

            let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: params)
            query.fields = "id"

            _ = try await self.googleDriveService.executeQuery(query)
        }.account
    }

    public func importBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        try await perform { pinned in
            try await self.importBackup(account: account, password: password, pinned: pinned)
        }.value
    }

    public func importBackup(
        account: OpenBackupAccount,
        password: String,
        expectedAccountUserID: String
    ) async throws -> OpenBackupAccount {
        guard !expectedAccountUserID.isEmpty else {
            throw CloudStorageServiceError.accountChanged
        }
        let backup = try await perform(expecting: expectedAccountUserID) { pinned in
            try await self.importBackup(account: account, password: password, pinned: pinned)
        }.value
        // Every request above was made as the expected account. If Google
        // was signed out or switched to another account meanwhile, anywhere
        // in the app, the backup that was read is not handed on.
        let signedIn = singInProvider.currentUser
        guard signedIn.flatMap(Self.identity(of:))?.userID == expectedAccountUserID else {
            if let signedIn, Self.identity(of: signedIn) == nil {
                await signOutUnnamed(signedIn)
            }
            throw CloudStorageServiceError.accountChanged
        }
        return backup
    }

    private func importBackup(
        account: OpenBackupAccount,
        password: String,
        pinned: String
    ) async throws -> OpenBackupAccount {
        do {
            let mobileAccount = try await fetchBackup(
                account: account,
                password: password,
                pinned: pinned
            )
            return mobileAccount
        } catch {
            if let error = error as? CloudStorageServiceError {
                switch error {
                case .notFound:
                    let extensionAccount = try await executeExtension(
                        account: account,
                        password: password,
                        pinned: pinned
                    )
                    return extensionAccount
                case .incorectPassword, .incorectJson, .notAuthorized, .accountChanged:
                    throw error
                }
            }
            throw error
        }
    }

    public func deleteBackup(account: OpenBackupAccount) async throws {
        _ = try await deleteBackupNamingAccount(account: account)
    }

    public func deleteBackupNamingAccount(
        account: OpenBackupAccount
    ) async throws -> CloudStorageAccountIdentity? {
        try await perform { pinned -> Void in
            let mobileAccounts = try await self.getBackupAccountsForMobileExtension(pinned: pinned)
            let extensionAccounts = try await self.getBackupAccountsForFearlessExtension(pinned: pinned)

            if mobileAccounts.contains(where: { $0.address == account.address }) {
                try await self.delete(backupAccount: account, pinned: pinned)
                return
            } else if extensionAccounts.contains(where: { $0.address == account.address }) {
                throw FearlessExtensionError.cantRemoveExtensionBackup
            }

            throw FearlessExtensionError.backupNotFound
        }.account
    }

    public func disconnect() {
        singInProvider.signOut()
        singInProvider.disconnect(completion: nil)
        setAuthorizer(for: nil)
    }
}

extension CloudStorageService {
    private func signIn(uiDelegate: UIViewController) async throws -> GIDGoogleUser? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.queue.async { [weak self] in
                self?.singInProvider.signInForDrive(
                    presenting: uiDelegate,
                    scopes: [kGTLRAuthScopeDriveAppdata],
                    completion: { user, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: user)
                        }
                    }
                )
            }
        }
    }

    private func getBackupAccountsForMobileExtension(pinned: String) async throws -> [OpenBackupAccount] {
        try await authorizeStep(pinned)

        let folderId = try await getParentFolder()

        let q = "'\(folderId)' in parents"
        let files = try await getAppFolderFiles(from: q, withField: true)

        let accounts = files.map {
            OpenBackupAccount(
                name: $0.descriptionProperty,
                address: String($0.name?.split(separator: ".").first ?? "")
            )
        }

        return accounts
    }

    private func getBackupAccountsForFearlessExtension(pinned: String) async throws -> [OpenBackupAccount] {
        try await authorizeStep(pinned)

        let q = "'appDataFolder' in parents and mimeType != 'application/vnd.google-apps.folder'"
        let files = try await getAppFolderFiles(from: q, withField: true)

        let accounts: [OpenBackupAccount] = files.compactMap {
            guard let descriptionProperty = $0.descriptionProperty,
                  descriptionProperty.contains("/") == true,
                  let addressSubSequence = $0.descriptionProperty?.split(separator: "/").first,
                  let ethereumJsonFileId = $0.descriptionProperty?.split(separator: "/").last else
            {
                return nil
            }

            return OpenBackupAccount(
                name: $0.name?.replacingOccurrences(of: ".json", with: ""),
                address: String(addressSubSequence),
                ethDerivationPath: String(ethereumJsonFileId)
            )
        }

        return accounts
    }

    private func fetchBackup(
        account: OpenBackupAccount,
        password: String,
        pinned: String
    ) async throws -> OpenBackupAccount {
        try await authorizeStep(pinned)

        let files = try await getAppFolderFiles()

        guard let fileId = files.first(where: { $0.name?.contains(account.address) ?? false })?
            .identifier else
        {
            throw CloudStorageServiceError.notFound
        }

        let data = try await executeQueryForMedia(withFileId: fileId)
        return try Self.openBackup(
            data,
            password: password,
            expectedAddress: account.address,
            encryptionService: encryptionService
        )
    }

    /// Decrypts a backup file and proves the password.
    ///
    /// - With a key verifier (written by newer apps): it must decrypt to the
    ///   backup address.
    /// - Without one (App Store SORA 3.8.6 and earlier never wrote it): at
    ///   least one secret field must be present, and every non-empty encrypted
    ///   field must decrypt. The encryption is authenticated
    ///   (XSalsa20-Poly1305), so a wrong password cannot decrypt.
    ///
    /// An oversized file, or a field that `EncryptionService` rejects as
    /// malformed before key derivation, is `incorectJson`, not a password error.
    ///
    /// The caller must still check that the restored phrase, seed or JSON
    /// derives `address` before saving anything.
    public static func openBackup(
        _ data: Data,
        password: String,
        expectedAddress: String? = nil,
        encryptionService: EncryptionServiceProtocol = EncryptionService()
    ) throws -> OpenBackupAccount {
        guard !data.isEmpty, data.count <= EncryptionService.maximumBackupBytes else {
            throw CloudStorageServiceError.incorectJson
        }
        guard let account = try? JSONDecoder().decode(EcryptedBackupAccount.self, from: data) else {
            throw CloudStorageServiceError.incorectJson
        }
        if let expectedAddress, account.address != expectedAddress {
            throw CloudStorageServiceError.notFound
        }

        func decrypt(_ value: String?) throws -> String? {
            guard let value, !value.isEmpty else { return nil }
            let decrypted: String?
            do {
                decrypted = try encryptionService.getDecrypted(from: value, password: password)
            } catch CloudStorageServiceError.incorectJson {
                // Malformed or outside the scrypt bounds: no password can open it.
                throw CloudStorageServiceError.incorectJson
            } catch {
                throw CloudStorageServiceError.incorectPassword
            }
            guard let plaintext = decrypted else {
                throw CloudStorageServiceError.incorectPassword
            }
            return plaintext
        }

        if let keyVerifier = account.keyVerifier, !keyVerifier.isEmpty {
            guard try decrypt(keyVerifier) == account.address else {
                throw CloudStorageServiceError.incorectPassword
            }
        } else {
            let hasSecret = [
                account.encryptedMnemonicPhrase,
                account.encryptedSeed?.substrateSeed,
                account.json?.substrateJson,
            ].contains { ($0 ?? "").isEmpty == false }
            guard hasSecret else {
                throw CloudStorageServiceError.incorectJson
            }
        }

        let passphrase = try decrypt(account.encryptedMnemonicPhrase)
        let substrateDerivationPath = try decrypt(account.encryptedSubstrateDerivationPath)
        let ethDerivationPath = try decrypt(account.encryptedEthDerivationPath)
        let substrateSeed = try decrypt(account.encryptedSeed?.substrateSeed)
        let ethereumSeed = try decrypt(account.encryptedSeed?.ethSeed)

        return OpenBackupAccount(
            name: account.name,
            address: account.address,
            passphrase: passphrase,
            cryptoType: account.cryptoType,
            substrateDerivationPath: substrateDerivationPath,
            ethDerivationPath: ethDerivationPath,
            backupAccountType: account.backupAccountType?
                .compactMap {
                    OpenBackupAccount.BackupAccountType(rawValue: $0)
                },
            json: OpenBackupAccount.Json(
                substrateJson: account.json?.substrateJson,
                ethJson: account.json?.ethJson
            ),
            encryptedSeed: OpenBackupAccount.Seed(
                substrateSeed: substrateSeed,
                ethSeed: ethereumSeed
            )
        )
    }

    private func executeExtension(
        account: OpenBackupAccount,
        password: String,
        pinned: String
    ) async throws -> OpenBackupAccount {
        try await authorizeStep(pinned)

        let q = "'appDataFolder' in parents and mimeType != 'application/vnd.google-apps.folder'"
        let extensionAccounts = try await getAppFolderFiles(
            from: q,
            withField: true
        )

        guard let fileId = extensionAccounts.first(where: {
            $0.descriptionProperty?.contains(account.address) == true
        })?.identifier,
            let ethereumFileId = account.ethDerivationPath else
        {
            throw CloudStorageServiceError.notFound
        }

        let substrateData = try await executeQueryForMedia(withFileId: fileId)
        let ethereumData = try await executeQueryForMedia(withFileId: ethereumFileId)
        return try OpenBackupAccount.create(
            address: account.address,
            password: password,
            substrateData: substrateData,
            ethereumData: ethereumData
        )
    }

    private func delete(backupAccount: OpenBackupAccount, pinned: String) async throws {
        try await authorizeStep(pinned)

        let files = try await getAppFolderFiles()

        guard let fileId = files.first(where: { file in
            file.name == "\(backupAccount.address).json"
        })?.identifier else {
            throw CloudStorageServiceError.notFound
        }

        try await googleDriveService
            .executeQuery(GTLRDriveQuery_FilesDelete.query(withFileId: fileId))
    }
}
