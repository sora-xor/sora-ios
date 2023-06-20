import UIKit
import FearlessUtils
import RobinHood
import SoraKeystore

final class AccountExportInteractor {
    weak var presenter: AccountExportInteractorOutputProtocol!

    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    private let accounts: [AccountItem]

    init(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        accounts: [AccountItem]
    ) {
        self.keystore = keystore
        self.settings = settings
        self.accounts = accounts
    }
}

extension AccountExportInteractor: AccountExportInteractorInputProtocol {

    func exportToFileWith(password: String) -> NSURL? {
        guard !accounts.isEmpty else { return nil }
        if accounts.count == 1 {
            return exportAccountToFile(account: accounts[0], password: password)
        } else {
            return exportAccountsToFile(accounts: accounts, password: password)
        }
    }

    private func exportAccountToFile(account: AccountItem, password: String) -> NSURL? {
        do {
            _ = try keystore.fetchSecretKeyForAddress(account.address)
            let exportData: Data = try KeystoreExportWrapper(keystore: keystore).export(account: account, password: password)
            let url = exportData.saveToFile(name: "\(account.address).json") ?? .init()
            return url
        } catch {
            print("Error KeystoreExport to file: \(error.localizedDescription)")
            return nil
        }
    }

    private func exportAccountsToFile(accounts: [AccountItem], password: String) -> NSURL? {
        guard let account = accounts.first else { return nil }
        do {
            _ = try keystore.fetchSecretKeyForAddress(account.address)
            let exportData: Data = try KeystoreExportWrapper(keystore: keystore).export(accounts: accounts, password: password)
            let url = exportData.saveToFile(name: "batch_exported_account_\(Date().timeIntervalSince1970).json") ?? .init()
            return url
        } catch {
            print("Error KeystoreExport to file: \(error.localizedDescription)")
            return nil
        }
    }
}

extension Data {
    func saveToFile(name: String) -> NSURL? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let filePath = (paths[0] as NSString).appendingPathComponent(name)
        do {
            try self.write(to: URL(fileURLWithPath: filePath))
            return NSURL(fileURLWithPath: filePath)
        } catch {
            print("Error writing the file: \(error.localizedDescription)")
        }
        return nil
    }
}
