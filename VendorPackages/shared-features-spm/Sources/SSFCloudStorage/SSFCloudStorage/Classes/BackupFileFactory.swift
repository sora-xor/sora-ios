import Foundation

public protocol BackupFileFactoryProtocol {
    func createFile(from account: OpenBackupAccount, password: String) throws -> URL
    /// The encrypted backup of one save, made in memory: no file is written,
    /// so saves of the same wallet cannot read or remove each other's backup.
    func createBackupData(from account: OpenBackupAccount, password: String) throws -> Data
}

public extension BackupFileFactoryProtocol {
    /// For a factory that only writes files: the file is read, and removed
    /// when it is in the temporary directory.
    func createBackupData(from account: OpenBackupAccount, password: String) throws -> Data {
        let fileUrl = try createFile(from: account, password: password)
        defer {
            let temporary = FileManager.default.temporaryDirectory.standardizedFileURL
            if fileUrl.deletingLastPathComponent().standardizedFileURL == temporary {
                try? FileManager.default.removeItem(at: fileUrl)
            }
        }
        return try Data(contentsOf: fileUrl)
    }
}

public class BackupFileFactory: NSObject, BackupFileFactoryProtocol {
    private let service: EncryptionServiceProtocol

    init(service: EncryptionServiceProtocol) {
        self.service = service
    }

    public func createFile(from account: OpenBackupAccount, password: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(account.address)")
            .appendingPathExtension("json")
        let data = try createBackupData(from: account, password: password)
        // Readable only while the iPhone is unlocked. The caller deletes it
        // once it has read it.
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    public func createBackupData(from account: OpenBackupAccount, password: String) throws -> Data {
        let keyVerifier = try service.createEncryptedData(
            with: password,
            message: account.address
        )

        let encodedPassphrase = try service.createEncryptedData(
            with: password,
            message: account.passphrase
        )
        let encodedSubstrateDerivationPath = try service.createEncryptedData(
            with: password,
            message: account.substrateDerivationPath
        )
        let encodedEthDerivationPath = try service.createEncryptedData(
            with: password,
            message: account.ethDerivationPath
        )
        let encodedSubstrateSeed = try service.createEncryptedData(
            with: password,
            message: account.encryptedSeed?.substrateSeed
        )
        let encodedEthSeed = try service.createEncryptedData(
            with: password,
            message: account.encryptedSeed?.ethSeed
        )

        let encryptedSeed = OpenBackupAccount.Seed(
            substrateSeed: encodedSubstrateSeed?.toHex(),
            ethSeed: encodedEthSeed?.toHex()
        )

        let ecryptedBackupAccount = EcryptedBackupAccount(
            name: account.name ?? "",
            address: account.address,
            keyVerifier: keyVerifier?.toHex(),
            encryptedMnemonicPhrase: encodedPassphrase?.toHex(),
            encryptedSubstrateDerivationPath: encodedSubstrateDerivationPath?.toHex(),
            encryptedEthDerivationPath: encodedEthDerivationPath?.toHex(),
            cryptoType: account.cryptoType,
            backupAccountType: account.backupAccountType.map { $0.map { $0.rawValue }},
            json: account.json,
            encryptedSeed: encryptedSeed
        )

        return try JSONEncoder().encode(ecryptedBackupAccount)
    }
}
