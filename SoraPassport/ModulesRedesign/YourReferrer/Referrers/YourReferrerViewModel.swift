import UIKit
import SoraUIKit

protocol YourReferrerViewModelProtocol: AnyObject {
    var referrer: String { get }
    var delegate: YourReferrerCellDelegate { get }
}

final class YourReferrerViewModel: YourReferrerViewModelProtocol {
    var referrer: String
    var delegate: YourReferrerCellDelegate
    
    init(referrer: String,
         delegate: YourReferrerCellDelegate) {
        self.referrer = referrer
        self.delegate = delegate
    }
}

extension YourReferrerViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return YourReferrerCell.reuseIdentifier
    }
}
