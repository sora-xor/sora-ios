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

public struct CloudStorageAccountIdentity: Equatable {
    public let userID: String
    public let email: String
    public let name: String?

    public init(userID: String, email: String, name: String? = nil) {
        self.userID = userID
        self.email = email
        self.name = name
    }
}

public protocol CloudStorageServiceProtocol: AnyObject {
    var isUserAuthorized: Bool { get }
    var currentAccountIdentity: CloudStorageAccountIdentity? { get }
    @MainActor func configureCurrentAccountIfAvailable() -> CloudStorageAccountState
    func restorePreviousSignInIfAvailable() async throws -> CloudStorageAccountState
    func importMobileBackupIfAuthorized(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount
    func importMobileBackupIfAuthorized(
        account: OpenBackupAccount,
        password: String,
        expectedAccountUserID: String
    ) async throws -> OpenBackupAccount
    func containsMobileBackupIfAuthorized(
        address: String,
        expectedAccountUserID: String
    ) async throws -> Bool
    func signInIfNeeded() async throws -> CloudStorageAccountState
    func signInSelectingAccount() async throws -> CloudStorageAccountIdentity?
    func getBackupAccounts() async throws -> [OpenBackupAccount]
    func saveBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> CloudStorageAccountIdentity
    func importBackup(account: OpenBackupAccount, password: String) async throws
        -> OpenBackupAccount
    func deleteBackup(
        account: OpenBackupAccount
    ) async throws -> CloudStorageAccountIdentity
    func disconnect()
}

protocol GoogleDriveServiceProtocol: AnyObject {
    var googleDriveService: GoogleService { get }
}

public class CloudStorageService: NSObject, GoogleDriveServiceProtocol {
    public var isUserAuthorized: Bool { singInProvider.currentUser != nil }
    public var currentAccountIdentity: CloudStorageAccountIdentity? {
        singInProvider.currentUser.flatMap(accountIdentity(for:))
    }
    public var googleDriveService: GoogleService

    private weak var uiDelegate: UIViewController?
    private let singInProvider: GIDSignIn
    private let queue: DispatchQueueType
    private let encryptionService: EncryptionServiceProtocol
    private let fileFactory: BackupFileFactoryProtocol
    private var hasConfiguredDriveAuthorizer = false
    private var configuredAccountIdentity: CloudStorageAccountIdentity?

    public init(
        uiDelegate: UIViewController?,
        signInProvider: GIDSignIn = GIDSignIn.sharedInstance,
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
    /// Configures Drive only from Google's already-loaded in-memory user. This performs no
    /// Keychain read, token restoration, network request, or authentication UI.
    @MainActor public func configureCurrentAccountIfAvailable() -> CloudStorageAccountState {
        guard let user = singInProvider.currentUser else {
            clearDriveAuthorization()
            return .notAuthorized
        }
        return configureDriveAuthorizerIfPermitted(for: user)
    }

    public func restorePreviousSignInIfAvailable() async throws -> CloudStorageAccountState {
        if await MainActor.run(body: { singInProvider.currentUser != nil }) {
            return await configureCurrentAccountIfAvailable()
        }

        guard singInProvider.hasPreviousSignIn() else {
            clearDriveAuthorization()
            return .notAuthorized
        }

        guard let user = try await restorePreviousSignIn() else {
            clearDriveAuthorization()
            return .notAuthorized
        }

        return configureDriveAuthorizerIfPermitted(for: user)
    }

    /// Fetches only the canonical mobile backup after a caller has restored an existing
    /// Google session. This API never attempts interactive sign-in and never falls back to
    /// the broad Fearless-extension lookup.
    public func importMobileBackupIfAuthorized(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        guard hasConfiguredDriveAuthorizer else {
            throw CloudStorageServiceError.notAuthorized
        }

        return try await fetchAuthorizedMobileBackup(
            account: account,
            password: password
        )
    }

    /// Reads a backup only when the Drive authorizer still belongs to the exact Google
    /// identity confirmed by the user on the recovery screen.
    public func importMobileBackupIfAuthorized(
        account: OpenBackupAccount,
        password: String,
        expectedAccountUserID: String
    ) async throws -> OpenBackupAccount {
        guard hasConfiguredDriveAuthorizer,
              configuredAccountIdentity?.userID == expectedAccountUserID else {
            throw CloudStorageServiceError.notAuthorized
        }

        return try await fetchAuthorizedMobileBackup(
            account: account,
            password: password
        )
    }

    /// Confirms that the exact Google identity has an app-owned backup whose filename and
    /// outer address name the requested wallet. No password or key material is read.
    public func containsMobileBackupIfAuthorized(
        address: String,
        expectedAccountUserID: String
    ) async throws -> Bool {
        guard hasConfiguredDriveAuthorizer,
              configuredAccountIdentity?.userID == expectedAccountUserID else {
            throw CloudStorageServiceError.notAuthorized
        }

        return try await authorizedMobileBackupEnvelope(for: address) != nil
    }

    public func signInIfNeeded() async throws -> CloudStorageAccountState {
        if (try? await restorePreviousSignInIfAvailable()) == .authorized {
            return .authorized
        }

        guard let uiDelegate = uiDelegate else {
            return .notAuthorized
        }

        if let user = singInProvider.currentUser {
            let scopedUser = try await addDriveScopeIfNeeded(
                to: user,
                uiDelegate: uiDelegate
            )
            return configureDriveAuthorizerIfPermitted(for: scopedUser)
        }

        let result = try await signIn(
            uiDelegate: uiDelegate,
            forceAccountSelection: false
        )
        guard let user = result?.user else {
            clearDriveAuthorization()
            return .notAuthorized
        }
        return configureDriveAuthorizerIfPermitted(for: user)
    }

    /// Starts interactive Google sign-in and requires Google's account selector.
    public func signInSelectingAccount() async throws -> CloudStorageAccountIdentity? {
        guard let uiDelegate else {
            return nil
        }

        let result = try await signIn(
            uiDelegate: uiDelegate,
            forceAccountSelection: true
        )
        guard let user = result?.user else {
            clearDriveAuthorization()
            return nil
        }
        guard configureDriveAuthorizerIfPermitted(for: user) == .authorized else {
            return nil
        }
        return configuredAccountIdentity
    }

    public func getBackupAccounts() async throws -> [OpenBackupAccount] {
        let mobileAccounts = try await getBackupAccountsForMobileExtension()
        let extensionAccounts = try await getBackupAccountsForFearlessExtension()

        let filteredExtensionAccounts = extensionAccounts.filter { extensionAccount in
            !mobileAccounts.contains(where: { $0.address == extensionAccount.address })
        }
        let accounts = mobileAccounts + filteredExtensionAccounts
        return accounts
    }

    public func saveBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> CloudStorageAccountIdentity {
        let fileUrl = try fileFactory.createFile(from: account, password: password)
        let data = try Data(contentsOf: fileUrl)

        let signInState = try await signInIfNeeded()

        guard signInState == .authorized,
              let authorizedIdentity = configuredAccountIdentity else {
            throw CloudStorageServiceError.notAuthorized
        }

        let folderId = try await getParentFolder()

        let file = GTLRDrive_File()
        file.name = "\(account.address).json"
        file.descriptionProperty = account.name

        let params = GTLRUploadParameters(data: data, mimeType: "application/json")
        params.shouldUploadWithSingleRequest = true

        let fileName = "\(account.address).json"
        let escapedFileName = fileName.replacingOccurrences(of: "'", with: "\\'")
        let existingFiles = try await getAppFolderFiles(
            from: "name = '\(escapedFileName)' and '\(folderId)' in parents and trashed = false",
            withField: true
        )

        if let fileId = existingFiles.first(where: { $0.name == fileName })?.identifier {
            let query = GTLRDriveQuery_FilesUpdate.query(
                withObject: file,
                fileId: fileId,
                uploadParameters: params
            )
            query.fields = "id"
            try await googleDriveService.executeQuery(query)
        } else {
            file.parents = [folderId]
            let query = GTLRDriveQuery_FilesCreate.query(
                withObject: file,
                uploadParameters: params
            )
            query.fields = "id"
            try await googleDriveService.executeQuery(query)
        }
        return authorizedIdentity
    }

    public func importBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        do {
            let mobileAccount = try await fetchBackup(account: account, password: password)
            return mobileAccount
        } catch {
            if let error = error as? CloudStorageServiceError {
                switch error {
                case .notFound:
                    let extensionAccount = try await executeExtension(
                        account: account,
                        password: password
                    )
                    return extensionAccount
                case .incorectPassword, .incorectJson, .notAuthorized:
                    throw error
                }
            }
            throw error
        }
    }

    public func deleteBackup(
        account: OpenBackupAccount
    ) async throws -> CloudStorageAccountIdentity {
        let mobileAccounts = try await getBackupAccountsForMobileExtension()
        let extensionAccounts = try await getBackupAccountsForFearlessExtension()

        if mobileAccounts.contains(where: { $0.address == account.address }) {
            return try await delete(backupAccount: account)
        } else if extensionAccounts.contains(where: { $0.address == account.address }) {
            throw FearlessExtensionError.cantRemoveExtensionBackup
        }

        throw FearlessExtensionError.backupNotFound
    }

    public func disconnect() {
        singInProvider.signOut()
        singInProvider.disconnect()
        clearDriveAuthorization()
    }
}

extension CloudStorageService {
    private func accountIdentity(
        for user: GIDGoogleUser
    ) -> CloudStorageAccountIdentity? {
        guard let profile = user.profile else {
            return nil
        }

        let userID = (user.userID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty, !email.isEmpty else {
            return nil
        }

        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return CloudStorageAccountIdentity(
            userID: userID,
            email: email,
            name: name.isEmpty ? nil : name
        )
    }

    private func clearDriveAuthorization() {
        googleDriveService.set(authorizer: nil)
        hasConfiguredDriveAuthorizer = false
        configuredAccountIdentity = nil
    }

    private func hasDriveAppDataScope(_ user: GIDGoogleUser) -> Bool {
        user.grantedScopes?.contains(kGTLRAuthScopeDriveAppdata) == true
    }

    private func configureDriveAuthorizerIfPermitted(
        for user: GIDGoogleUser
    ) -> CloudStorageAccountState {
        guard hasDriveAppDataScope(user),
              let identity = accountIdentity(for: user) else {
            clearDriveAuthorization()
            return .notAuthorized
        }

        googleDriveService.set(authorizer: user.fetcherAuthorizer)
        hasConfiguredDriveAuthorizer = true
        configuredAccountIdentity = identity
        return .authorized
    }

    private func addDriveScopeIfNeeded(
        to user: GIDGoogleUser,
        uiDelegate: UIViewController
    ) async throws -> GIDGoogleUser {
        guard !hasDriveAppDataScope(user) else {
            return user
        }

        return try await withCheckedThrowingContinuation { continuation in
            user.addScopes(
                [kGTLRAuthScopeDriveAppdata],
                presenting: uiDelegate
            ) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let scopedUser = result?.user {
                    continuation.resume(returning: scopedUser)
                } else {
                    continuation.resume(throwing: CloudStorageServiceError.notAuthorized)
                }
            }
        }
    }

    private func restorePreviousSignIn() async throws -> GIDGoogleUser? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(returning: nil)
                return
            }

            singInProvider.restorePreviousSignIn { user, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: user)
                }
            }
        }
    }

    private func signIn(
        uiDelegate: UIViewController,
        forceAccountSelection: Bool
    ) async throws -> GIDSignInResult? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(returning: nil)
                return
            }
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                singInProvider.signIn(
                    withPresenting: uiDelegate,
                    hint: nil,
                    additionalScopes: [kGTLRAuthScopeDriveAppdata],
                    forceAccountSelection: forceAccountSelection,
                    completion: { result, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: result)
                        }
                    }
                )
            }
        }
    }

    private func getBackupAccountsForMobileExtension() async throws -> [OpenBackupAccount] {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

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

    private func getBackupAccountsForFearlessExtension() async throws -> [OpenBackupAccount] {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

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
        password: String
    ) async throws -> OpenBackupAccount {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        return try await fetchAuthorizedMobileBackup(
            account: account,
            password: password
        )
    }

    private func fetchAuthorizedMobileBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        let requestedAddress = account.address
        guard let account = try await authorizedMobileBackupEnvelope(for: requestedAddress) else {
            throw CloudStorageServiceError.notFound
        }

        try validatePassword(
            for: account,
            requestedAddress: requestedAddress,
            password: password
        )

        let passphrase = try? encryptionService.getDecrypted(
            from: account.encryptedMnemonicPhrase,
            password: password
        )
        let substrateDerivationPath = try? encryptionService.getDecrypted(
            from: account.encryptedSubstrateDerivationPath,
            password: password
        )

        var ethDerivationPath: String?

        if let path = account.encryptedEthDerivationPath, !path.isEmpty {
            guard let ethPath = try? encryptionService.getDecrypted(from: path, password: password) else {
                throw CloudStorageServiceError.incorectPassword
            }
            ethDerivationPath = ethPath
        }

        let encryptedSeed = account.encryptedSeed
        let substrateSeed = try? encryptionService.getDecrypted(
            from: encryptedSeed?.substrateSeed,
            password: password
        )
        let ethereumSeed = try? encryptionService.getDecrypted(
            from: encryptedSeed?.ethSeed,
            password: password
        )

        let decodedAccount = OpenBackupAccount(
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

        return decodedAccount
    }

    private func authorizedMobileBackupEnvelope(
        for requestedAddress: String
    ) async throws -> EcryptedBackupAccount? {
        let fileName = "\(requestedAddress).json"
        let escapedFileName = fileName.replacingOccurrences(of: "'", with: "\\'")
        let files = try await getAppFolderFiles(
            from: "name = '\(escapedFileName)' and trashed = false",
            withField: true
        )

        guard let fileId = files.first(where: { $0.name == fileName })?.identifier else {
            return nil
        }

        let data = try await executeQueryForMedia(withFileId: fileId)
        guard
            let account = try? JSONDecoder().decode(EcryptedBackupAccount.self, from: data),
            account.address == requestedAddress
        else {
            throw CloudStorageServiceError.incorectJson
        }

        return account
    }

    private func validatePassword(
        for account: EcryptedBackupAccount,
        requestedAddress: String,
        password: String
    ) throws {
        if let keyVerifier = account.keyVerifier {
            guard isExpectedEncryptedPayload(keyVerifier),
                  let decryptedAddress = try? encryptionService.getDecrypted(
                      from: keyVerifier,
                      password: password
                  ),
                  decryptedAddress == requestedAddress
            else {
                throw CloudStorageServiceError.incorectPassword
            }

            return
        }

        let encryptedKeyMaterial = [
            account.encryptedMnemonicPhrase,
            account.encryptedSeed?.substrateSeed,
            account.encryptedSeed?.ethSeed,
        ].compactMap { $0 }

        let authenticatedKeyMaterial = encryptedKeyMaterial.contains { material in
            guard isExpectedEncryptedPayload(material) else {
                return false
            }

            do {
                return try encryptionService.getDecrypted(
                    from: material,
                    password: password
                ) != nil
            } catch {
                return false
            }
        }

        guard authenticatedKeyMaterial ||
            isAuthenticatedLegacySubstrateJSON(
                account.json?.substrateJson,
                password: password
            )
        else {
            throw CloudStorageServiceError.incorectPassword
        }
    }

    private func isExpectedEncryptedPayload(_ value: String) -> Bool {
        guard let data = try? Data(hexStringSSF: value),
              data.count >= ScryptParameters.encodedLength + KeystoreConstants.nonceLength + 16,
              let parameters = try? ScryptParameters(data: data)
        else {
            return false
        }

        return parameters.scryptN == 32_768 &&
            parameters.scryptP == 1 &&
            parameters.scryptR == 8
    }

    private func isAuthenticatedLegacySubstrateJSON(
        _ value: String?,
        password: String
    ) -> Bool {
        guard let value,
              let jsonData = value.data(using: .utf8),
              let definition = try? JSONDecoder().decode(
                  KeystoreDefinition.self,
                  from: jsonData
              ),
              definition.encoding.content == ["pkcs8", "sr25519"],
              definition.encoding.type == ["scrypt", "xsalsa20-poly1305"],
              let encodedData = Data(base64Encoded: definition.encoded),
              encodedData.count >=
                ScryptParameters.encodedLength + KeystoreConstants.nonceLength + 16,
              let parameters = try? ScryptParameters(data: encodedData),
              parameters.scryptN == 32_768,
              parameters.scryptP == 1,
              parameters.scryptR == 8,
              let passwordData = password.data(using: .utf8)
        else {
            return false
        }

        do {
            let encryptionKey = try IRScryptKeyDeriviation().deriveKey(
                from: passwordData,
                salt: parameters.salt,
                scryptN: UInt(parameters.scryptN),
                scryptP: UInt(parameters.scryptP),
                scryptR: UInt(parameters.scryptR),
                length: UInt(KeystoreConstants.encryptionKeyLength)
            )
            let nonceStart = ScryptParameters.encodedLength
            let nonceEnd = nonceStart + KeystoreConstants.nonceLength
            let nonce = Data(encodedData[nonceStart ..< nonceEnd])
            let encryptedData = Data(encodedData[nonceEnd...])
            let decryptedData = try NaclSecretBox.open(
                box: encryptedData,
                nonce: nonce,
                key: encryptionKey
            )

            return decryptedData.count == 117
        } catch {
            return false
        }
    }

    private func executeExtension(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

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

    private func delete(
        backupAccount: OpenBackupAccount
    ) async throws -> CloudStorageAccountIdentity {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized,
              let authorizedIdentity = configuredAccountIdentity else {
            throw CloudStorageServiceError.notAuthorized
        }

        let files = try await getAppFolderFiles()

        guard let fileId = files.first(where: { file in
            file.name == "\(backupAccount.address).json"
        })?.identifier else {
            throw CloudStorageServiceError.notFound
        }

        try await googleDriveService
            .executeQuery(GTLRDriveQuery_FilesDelete.query(withFileId: fileId))
        return authorizedIdentity
    }
}
