import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class ContactViewModel: ContactViewModelProtocol {
    var cellReuseIdentifier: String { "" }
    
    var itemHeight: CGFloat { return 0 }
    
    var command: WalletCommandProtocol?

    let firstName: String
    let lastName: String
    let accountId: String
    let image: UIImage?
    let name: String

    init(firstName: String,
         lastName: String,
         accountId: String,
         image: UIImage?,
         name: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.accountId = accountId
        self.image = image
        self.name = name
    }
}
