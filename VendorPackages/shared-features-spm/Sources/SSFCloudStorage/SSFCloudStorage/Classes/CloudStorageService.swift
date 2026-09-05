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

public protocol CloudStorageServiceProtocol: AnyObject {
    var isUserAuthorized: Bool { get }
    func signInIfNeeded() async throws -> CloudStorageAccountState
    func getBackupAccounts() async throws -> [OpenBackupAccount]
    func saveBackup(account: OpenBackupAccount, password: String) async throws
    func importBackup(account: OpenBackupAccount, password: String) async throws
        -> OpenBackupAccount
    func deleteBackup(account: OpenBackupAccount) async throws
    func disconnect()
}

protocol GoogleDriveServiceProtocol: AnyObject {
    var googleDriveService: GoogleService { get }
}

public class CloudStorageService: NSObject, GoogleDriveServiceProtocol {
    public var isUserAuthorized: Bool { singInProvider.currentUser != nil }
    public var googleDriveService: GoogleService

    private weak var uiDelegate: UIViewController?
    private let singInProvider: GIDSignIn
    private let queue: DispatchQueueType
    private let encryptionService: EncryptionServiceProtocol
    private let fileFactory: BackupFileFactoryProtocol

    public init(
        uiDelegate: UIViewController,
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
    public func signInIfNeeded() async throws -> CloudStorageAccountState {
        guard let uiDelegate = uiDelegate else {
            return .notAuthorized
        }

        if let user = singInProvider.currentUser {
            googleDriveService.set(authorizer: user.fetcherAuthorizer)
            return .authorized
        }

        let result = try await signIn(uiDelegate: uiDelegate)
        googleDriveService.set(authorizer: result?.user.fetcherAuthorizer)
        return .authorized
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

    public func saveBackup(account: OpenBackupAccount, password: String) async throws {
        let fileUrl = try fileFactory.createFile(from: account, password: password)
        let data = try Data(contentsOf: fileUrl)

        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        let folderId = try await getParentFolder()

        let file = GTLRDrive_File()
        file.name = "\(account.address).json"
        file.descriptionProperty = account.name
        file.parents = ["\(folderId)"]

        let params = GTLRUploadParameters(data: data, mimeType: "application/json")
        params.shouldUploadWithSingleRequest = true

        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: params)
        query.fields = "id"

        try await googleDriveService.executeQuery(query)
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

    public func deleteBackup(account: OpenBackupAccount) async throws {
        let mobileAccounts = try await getBackupAccountsForMobileExtension()
        let extensionAccounts = try await getBackupAccountsForFearlessExtension()

        if mobileAccounts.contains(where: { $0.address == account.address }) {
            try await delete(backupAccount: account)
            return
        } else if extensionAccounts.contains(where: { $0.address == account.address }) {
            throw FearlessExtensionError.cantRemoveExtensionBackup
        }

        throw FearlessExtensionError.backupNotFound
    }

    public func disconnect() {
        singInProvider.signOut()
        singInProvider.disconnect()
    }
}

extension CloudStorageService {
    private func signIn(uiDelegate: UIViewController) async throws -> GIDSignInResult? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.queue.async { [weak self] in
                self?.singInProvider.signIn(
                    withPresenting: uiDelegate,
                    hint: nil,
                    additionalScopes: [kGTLRAuthScopeDriveAppdata],
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

        let files = try await getAppFolderFiles()

        guard let fileId = files.first(where: { $0.name?.contains(account.address) ?? false })?
            .identifier else
        {
            throw CloudStorageServiceError.notFound
        }

        let data = try await executeQueryForMedia(withFileId: fileId)

        guard let account = try? JSONDecoder().decode(EcryptedBackupAccount.self, from: data) else {
            throw CloudStorageServiceError.incorectJson
        }

        guard let _ = try? encryptionService.getDecrypted(
            from: account.keyVerifier,
            password: password
        ) else {
            throw CloudStorageServiceError.incorectPassword
        }

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

    private func delete(backupAccount: OpenBackupAccount) async throws {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
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
    }
}
