import SSFCloudStorage

protocol AccountOptionsViewProtocol: ControllerBackedProtocol, AlertPresentable {
    func didReceive(username: String)
    func didReceive(address: String)
    func setupOptions(with backUpState: BackupState, hasEntropy: Bool)
    func showLoading()
    func hideLoading()
}

protocol AccountOptionsPresenterProtocol: AnyObject {
    func setup()
    func showPassphrase()
    func showRawSeed()
    func showJson()
    func doLogout()
    func didUpdateUsername(_ new: String)
    func copyToClipboard()
    func deleteBackup()
    func createBackup()
}

protocol AccountOptionsInteractorInputProtocol: AnyObject {
    func getMetadata() -> AccountCreationMetadata?
    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void)
    func logoutAndClean()
    func updateUsername(_ username: String)
    var currentAccount: AccountItem { get }
    var accountHasEntropy: Bool { get }
    func deleteBackup(completion: @escaping (Error?) -> Void)
    func signInToGoogleIfNeeded(completion: ((OpenBackupAccount) -> Void)?)
}

protocol AccountOptionsInteractorOutputProtocol: AnyObject {
    func restart()
    func close()
}

protocol AccountOptionsWireframeProtocol: Loadable {
    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showRawSeed(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showJson(account: AccountItem, from view: AccountOptionsViewProtocol?)
    func showRoot()
    func back(from view: AccountOptionsViewProtocol?)
    func showLogout(from view: AccountOptionsViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?)
    func setupBackupAccountPassword(on controller: AccountOptionsViewProtocol?,
                                    account: OpenBackupAccount,
                                    completion: @escaping () -> Void)
}

protocol AccountOptionsViewFactoryProtocol: AnyObject {
	static func createView(account: AccountItem) -> AccountOptionsViewProtocol?
}
