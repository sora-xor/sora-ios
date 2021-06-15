import UIKit
import IrohaCrypto
import RobinHood
import SoraKeystore

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol
    let supportedNetworkTypes: [Chain]
    let defaultNetwork: Chain

    init(mnemonicCreator: IRMnemonicCreatorProtocol,
         supportedNetworkTypes: [Chain],
         defaultNetwork: Chain) {
        self.mnemonicCreator = mnemonicCreator
        self.supportedNetworkTypes = supportedNetworkTypes
        self.defaultNetwork = defaultNetwork
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableNetworks: supportedNetworkTypes,
                                                   defaultNetwork: defaultNetwork,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
}

class AccountBackupInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let keystore: KeystoreProtocol
    let mnemonicCreator: IRMnemonicCreatorProtocol
    let settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol, mnemonicCreator: IRMnemonicCreatorProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.mnemonicCreator = mnemonicCreator
        self.settings = settings
    }

    private func loadPhrase() throws -> IRMnemonicProtocol {
        let entropy = try keystore.fetchEntropyForAddress(settings.selectedAccount!.address)
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy!)
        return mnemonic
    }
}

extension AccountBackupInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try loadPhrase()

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableNetworks: Chain.allCases,
                                                   defaultNetwork: .sora,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
}
