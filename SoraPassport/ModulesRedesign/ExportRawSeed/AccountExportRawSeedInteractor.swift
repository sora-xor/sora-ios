import UIKit
import FearlessUtils
import RobinHood
import SoraKeystore

final class AccountExportRawSeedInteractor {
    weak var presenter: AccountExportRawSeedInteractorOutputProtocol!

    private(set) var keystore: KeystoreProtocol
    private let account: AccountItem
    private var rawSeed = ""

    init(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) {
        self.keystore = keystore
        self.account = account
    }
}

extension AccountExportRawSeedInteractor: AccountExportRawSeedInteractorInputProtocol {
    func copyRawSeedToClipboard() {
        UIPasteboard.general.string = rawSeed
    }

    func exportRawSeed() {
        do {
            guard let expectedSeedData = try keystore.fetchSeedForAddress(account.address) else { return }
            rawSeed = expectedSeedData.toHex(includePrefix: true)
            presenter.set(rawSeed: rawSeed)
        } catch {
            print("Error Keystore fetching Seed For Address: \(account.address), \(error.localizedDescription)")
            // TODO: show error
            return
        }
    }
}
