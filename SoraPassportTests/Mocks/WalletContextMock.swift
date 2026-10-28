import Foundation
@testable import SoraPassport

class WalletCommandMock: WalletCommandProtocol {
    private(set) var executionCount: Int = 0

    func execute() throws {
        executionCount += 1
    }
}

final class WalletContextMock: CommonWalletContextProtocol {
    var networkOperationFactory: WalletNetworkOperationFactoryProtocol {get {return WalletNetworkOperationFactoryProtocolMock()}}

    var closurePrepareAccountUpdateCommand: (() -> WalletCommandProtocol)?
    var closurePrepareLanguageSwitch: ((WalletLanguage) -> WalletCommandProtocol)?

    func prepareAccountUpdateCommand() -> WalletCommandProtocol {
        return closurePrepareAccountUpdateCommand?() ?? WalletCommandMock()
    }

    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol {
        return closurePrepareLanguageSwitch?(newLanguage) ?? WalletCommandMock()
    }
}
