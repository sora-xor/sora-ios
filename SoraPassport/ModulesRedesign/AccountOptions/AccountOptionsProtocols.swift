protocol AccountOptionsViewProtocol: ControllerBackedProtocol {
    func didReceive(username: String, hasEntropy: Bool)
    func didReceive(address: String)
}

protocol AccountOptionsPresenterProtocol: AnyObject {
    func setup()
    func showPassphrase()
    func showRawSeed()
    func showJson()
    func doLogout()
    func didUpdateUsername(_ new: String)
    func copyToClipboard()
}

protocol AccountOptionsInteractorInputProtocol: AnyObject {
    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void)
    func logoutAndClean()
    func updateUsername(_ username: String)
    var currentAccount: AccountItem {get}
    var accountHasEntropy: Bool {get}
}

protocol AccountOptionsInteractorOutputProtocol: AnyObject {
    func restart()
    func close()
}

protocol AccountOptionsWireframeProtocol: AnyObject {
    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showRawSeed(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showJson(account: AccountItem, from view: AccountOptionsViewProtocol?)
    func showRoot()
    func back(from view: AccountOptionsViewProtocol?)
    func showLogout(from view: AccountOptionsViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?)
}

protocol AccountOptionsViewFactoryProtocol: AnyObject {
	static func createView(account: AccountItem) -> AccountOptionsViewProtocol?
}
