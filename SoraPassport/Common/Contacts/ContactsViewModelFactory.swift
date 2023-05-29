import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils
import RobinHood

public protocol ContactsFactoryWrapperProtocol {
    func createContactViewModelFromContact(_ contact: SearchData,
                                           parameters: ContactModuleParameters,
                                           locale: Locale,
                                           delegate: ContactViewModelDelegate?)
    -> ContactViewModelProtocol?
}


final class ContactsViewModelFactory: ContactsFactoryWrapperProtocol {
    private let iconGenerator = PolkadotIconGenerator()
    var dataStorageFacade: StorageFacadeProtocol

    init(dataStorageFacade: StorageFacadeProtocol) {
        self.dataStorageFacade = dataStorageFacade
    }

    func createContactViewModelFromContact(_ contact: SearchData,
                                           parameters: ContactModuleParameters,
                                           locale: Locale,
                                           delegate: ContactViewModelDelegate?)
    -> ContactViewModelProtocol? {
        do {
            guard parameters.accountId != contact.accountId else {
                return nil
            }

            let icon = try iconGenerator.generateFromAddress(contact.firstName)
                .imageWithFillColor(.white,
                                    size: CGSize(width: 24.0, height: 24.0),
                                    contentScale: UIScreen.main.scale)

            let viewModel = ContactViewModel(
                firstName: contact.firstName,
                lastName: contact.lastName,
                accountId: contact.accountId,
                image: icon,
                name: contact.firstName)
            return viewModel
        } catch {
            return nil
        }
    }
}
