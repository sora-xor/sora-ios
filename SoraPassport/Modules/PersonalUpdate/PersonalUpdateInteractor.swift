import Foundation
import RobinHood

final class PersonalUpdateInteractor {
	weak var presenter: PersonalUpdateInteractorOutputProtocol?

    private(set) var customerFacade: CustomerDataProviderFacadeProtocol
    private(set) var projectService: ProjectUnitServiceProtocol

    init(customerFacade: CustomerDataProviderFacadeProtocol,
         projectService: ProjectUnitServiceProtocol) {
        self.customerFacade = customerFacade
        self.projectService = projectService
    }

    private func setupCustomerDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<UserData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let userData), .update(let userData):
                    self?.presenter?.didReceive(user: userData)
                case .delete:
                    break
                }
            } else {
                self?.presenter?.didReceive(user: nil)
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveUserDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        customerFacade.userProvider.addObserver(self,
                                                deliverOn: .main,
                                                executing: changesBlock,
                                                failing: failBlock,
                                                options: options)
    }
}

extension PersonalUpdateInteractor: PersonalUpdateInteractorInputProtocol {
    func setup() {
        setupCustomerDataProvider()
    }

    func refresh() {
        customerFacade.userProvider.refresh()
    }

    func update(with info: PersonalInfo) {
        do {
           _ = try projectService.updateCustomer(with: info, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.presenter?.didUpdateUser(with: info)
                    case .failure(let error):
                        self.presenter?.didReceiveUserUpdate(error: error)
                    }
                }
            }
        } catch {
            presenter?.didReceiveUserUpdate(error: error)
        }
    }
}
