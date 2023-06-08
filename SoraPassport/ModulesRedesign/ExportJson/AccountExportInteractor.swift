import UIKit
import FearlessUtils
import RobinHood
import SoraKeystore

final class AccountExportInteractor {
    weak var presenter: AccountExportInteractorOutputProtocol!

    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    private let account: AccountItem

    init(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) {
        self.keystore = keystore
        self.settings = settings
        self.account = account
    }
}

extension AccountExportInteractor: AccountExportInteractorInputProtocol {
    func exportToFileWith(password: String) -> NSURL? {
        do {
            _ = try keystore.fetchSecretKeyForAddress(account.address)
            let exportData = try KeystoreExportWrapper(keystore: keystore).export(account: account, password: password)
            let url = exportData.saveToFile(name: "\(account.address).json") ?? .init()
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
